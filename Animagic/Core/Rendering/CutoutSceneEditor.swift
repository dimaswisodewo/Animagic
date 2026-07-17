//
//  CutoutSceneEditor.swift
//  Animagic
//
//  Created by dimaswisodewo on 15/07/26.
//

import RealityKit
import UIKit

struct CutoutSceneConfiguration {
    var physicalWidthOverride: Float?
    var simulationInterval: Float?
    var maximumObjectCount: Int?
    var showsShadow: Bool

    static let augmentedReality = Self(physicalWidthOverride: nil, simulationInterval: nil, maximumObjectCount: nil, showsShadow: false)
    static let virtualRoom = Self(physicalWidthOverride: 0.8, simulationInterval: nil, maximumObjectCount: 12, showsShadow: false)
}

enum CutoutPlacementResult: Equatable {
    case placed
    case loading(String)
    case limitReached(Int)
    case missingAsset
    case missingModel
    case creationFailed(String)
}

@MainActor
final class CutoutSceneEditor: SceneEditing {
    var cutoutAssets: [CutoutAsset]
    var selectedCutoutID: CutoutAsset.ID?
    var selectedAnimalArchetype: AnimalArchetype
    var selectedSpawnMode: SpawnMode
    var selectedContentType: PlacementContentType
    var selectedModelID: PlaceableUSDZModel.ID?
    var onPlacementResult: ((CutoutPlacementResult) -> Void)?

    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)? {
        didSet {
            interactionManager.onSelectionChanged = onSelectionChanged
        }
    }

    private let entityFactory: CutoutEntityFactory
    private let modelRepository: USDZModelRepository
    private let registry: SceneObjectRegistry
    private let interactionManager: ObjectInteractionManager
    private var interactionAdapter: ARViewInteractionAdapter?
    weak var arView: ARView?
    private let configuration: CutoutSceneConfiguration
    private var simulationAccumulator: Float = 0
    private var isLoadingModel = false

    var objectCount: Int { registry.objects.count }
    var maximumObjectCount: Int? { configuration.maximumObjectCount }

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedSpawnMode: SpawnMode,
        selectedContentType: PlacementContentType = .doodle,
        selectedModelID: PlaceableUSDZModel.ID? = nil,
        entityFactory: CutoutEntityFactory? = nil,
        modelRepository: USDZModelRepository? = nil,
        configuration: CutoutSceneConfiguration? = nil,
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil
    ) {
        let registry = SceneObjectRegistry()
        self.cutoutAssets = cutoutAssets
        self.selectedCutoutID = selectedCutoutID
        self.selectedAnimalArchetype = selectedAnimalArchetype
        self.selectedSpawnMode = selectedSpawnMode
        self.selectedContentType = selectedContentType
        self.selectedModelID = selectedModelID ?? PlaceableUSDZModel.all.first?.id
        self.entityFactory = entityFactory ?? CutoutEntityFactory()
        self.modelRepository = modelRepository ?? USDZModelRepository()
        self.configuration = configuration ?? .augmentedReality
        self.registry = registry
        interactionManager = ObjectInteractionManager(registry: registry)
        self.onSelectionChanged = onSelectionChanged
        interactionManager.onSelectionChanged = onSelectionChanged
        self.modelRepository.preload()
    }

    func attachInteraction(
        to arView: ARView,
        surfaceProjector: any SurfaceProjecting,
        onEmptyTap: @escaping (CGPoint) -> Void
    ) {
        self.arView = arView
        let adapter = ARViewInteractionAdapter(
            manager: interactionManager,
            surfaceProjector: surfaceProjector,
            onEmptyTap: onEmptyTap
        )
        adapter.attach(to: arView)
        interactionAdapter = adapter
    }

    func detachInteraction(clearSelection: Bool = true) {
        interactionAdapter?.detach()
        interactionAdapter = nil
        arView = nil
        if clearSelection {
            interactionManager.clearSelection()
        }
    }

    @discardableResult
    func placeOnPlane(
        at position: SIMD3<Float>,
        normal: SIMD3<Float> = [0, 1, 0],
        cameraTransform: simd_float4x4?
    ) -> CutoutPlacementResult {
        var stageTransform = matrix_identity_float4x4
        stageTransform.columns.3 = [position.x, position.y, position.z, 1]
        return place(
            at: stageTransform,
            cameraTransform: cameraTransform,
            spawnMode: .plane,
            supportSurfaceNormal: normal
        )
    }

    @discardableResult
    func placeRoaming(cameraTransform: simd_float4x4) -> CutoutPlacementResult {
        var spawnTransform = matrix_identity_float4x4
        let forward = -cameraTransform.forward
        let right = cameraTransform.right
        let up = cameraTransform.up
        let spawnPosition = cameraTransform.translation
            + (forward * 1.05)
            + (right * Float.random(in: -0.28...0.28))
            + (up * Float.random(in: -0.08...0.18))
        spawnTransform.columns.3 = [spawnPosition.x, spawnPosition.y, spawnPosition.z, 1]
        return place(
            at: spawnTransform,
            cameraTransform: cameraTransform,
            spawnMode: .cameraRoam,
            supportSurfaceNormal: [0, 1, 0]
        )
    }

    func update(deltaTime: Float) {
        guard !registry.isEmpty else { return }
        guard let simulationInterval = configuration.simulationInterval else {
            registry.forEach { $0.update(deltaTime: deltaTime) }
            return
        }
        simulationAccumulator += min(max(deltaTime, 0), 1.0 / 15.0)
        guard simulationAccumulator >= simulationInterval else { return }
        let step = min(simulationAccumulator, 1.0 / 15.0)
        simulationAccumulator = 0
        registry.forEach { $0.update(deltaTime: step) }
    }

    var placedObjectSelection: PlacedObjectSelection? {
        interactionManager.selection
    }

    var selectedObject: (any PlacedSceneObject)? {
        interactionManager.selectedObject
    }

    func handleTap(on entity: Entity?) -> Bool {
        interactionManager.handleTap(on: entity)
    }

    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype) {
        interactionManager.setSelectedAnimalArchetype(archetype)
    }

    func deleteSelectedObject() {
        interactionManager.deleteSelected()
    }

    private var selectedCutoutAsset: CutoutAsset? {
        if let selectedCutoutID,
           let selectedAsset = cutoutAssets.first(where: { $0.id == selectedCutoutID }) {
            return selectedAsset
        }
        return cutoutAssets.first
    }

    private func place(
        at transform: simd_float4x4,
        cameraTransform: simd_float4x4?,
        spawnMode: SpawnMode,
        supportSurfaceNormal: SIMD3<Float>
    ) -> CutoutPlacementResult {
        if let maximumObjectCount = configuration.maximumObjectCount,
           objectCount >= maximumObjectCount {
            return .limitReached(maximumObjectCount)
        }

        switch selectedContentType {
        case .doodle:
            return placeCutout(
                at: transform,
                cameraTransform: cameraTransform,
                spawnMode: spawnMode,
                supportSurfaceNormal: supportSurfaceNormal
            )
        case .model:
            return placeModel(
                at: transform,
                cameraTransform: cameraTransform,
                supportSurfaceNormal: supportSurfaceNormal
            )
        }
    }

    private func placeCutout(
        at transform: simd_float4x4,
        cameraTransform: simd_float4x4?,
        spawnMode: SpawnMode,
        supportSurfaceNormal: SIMD3<Float>
    ) -> CutoutPlacementResult {
        let objectID = UUID()
        guard let cutoutAsset = selectedCutoutAsset else {
            return .missingAsset
        }
        guard let cutout = try? entityFactory.makeEntity(
                  from: cutoutAsset,
                  archetype: selectedAnimalArchetype,
                  objectID: objectID,
                  physicalWidth: configuration.physicalWidthOverride,
                  showsShadow: configuration.showsShadow
              ) else {
            return .creationFailed("This doodle could not be created.")
        }

        let anchor = AnchorEntity(world: transform)
        anchor.addChild(cutout.root)
        guard let arView else {
            return .creationFailed("The scene is no longer available.")
        }
        arView.scene.addAnchor(anchor)

        let spawnOrientation = makeSpawnOrientation(
            cameraTransform: cameraTransform,
            anchorTransform: transform
        )
        registry.register(
            PlacedCutout(
                id: objectID,
                anchor: anchor,
                parts: cutout,
                archetype: selectedAnimalArchetype,
                spawnMode: spawnMode,
                initialYaw: spawnOrientation.yaw,
                initialRoll: spawnOrientation.roll,
                supportSurfaceNormal: simd_normalize(supportSurfaceNormal)
            )
        )
        return .placed
    }

    private func placeModel(
        at transform: simd_float4x4,
        cameraTransform: simd_float4x4?,
        supportSurfaceNormal: SIMD3<Float>
    ) -> CutoutPlacementResult {
        guard !isLoadingModel else {
            return .loading("Loading model…")
        }
        guard let selectedModelID,
              let model = PlaceableUSDZModel.model(withID: selectedModelID) else {
            return .missingModel
        }

        isLoadingModel = true
        modelRepository.loadClone(of: model) { [weak self] result in
            guard let self else { return }
            self.isLoadingModel = false
            guard let arView = self.arView else {
                self.onPlacementResult?(.creationFailed("The scene is no longer available."))
                return
            }
            if let maximumObjectCount = self.configuration.maximumObjectCount,
               self.objectCount >= maximumObjectCount {
                self.onPlacementResult?(.limitReached(maximumObjectCount))
                return
            }

            switch result {
            case .failure(let error):
                self.onPlacementResult?(
                    .creationFailed(error.localizedDescription)
                )
            case .success(let loadedEntity):
                let objectID = UUID()
                let anchor = AnchorEntity(world: transform)
                do {
                    let placedModel = try PlacedUSDZModel(
                        id: objectID,
                        anchor: anchor,
                        model: model,
                        loadedEntity: loadedEntity,
                        supportSurfaceNormal: simd_normalize(supportSurfaceNormal)
                    )
                    if let cameraTransform {
                        placedModel.interactionRoot.orientation = simd_quatf(
                            angle: cameraTransform.yawFacingCamera(from: transform.translation),
                            axis: [0, 1, 0]
                        )
                    }
                    arView.scene.addAnchor(anchor)
                    self.registry.register(placedModel)
                    self.onPlacementResult?(.placed)
                } catch {
                    self.onPlacementResult?(
                        .creationFailed(error.localizedDescription)
                    )
                }
            }
        }
        return .loading("Loading \(model.title)…")
    }

    private func makeSpawnOrientation(
        cameraTransform: simd_float4x4?,
        anchorTransform: simd_float4x4
    ) -> (yaw: Float, roll: Float) {
        let cameraFacingYaw: Float
        if let cameraTransform {
            let worldDirection = cameraTransform.translation - anchorTransform.translation
            let localDirection = anchorTransform.inverse * SIMD4<Float>(worldDirection, 0)
            cameraFacingYaw = atan2(localDirection.x, localDirection.z)
        } else {
            cameraFacingYaw = 0
        }
        return (
            yaw: cameraFacingYaw + Float.random(in: (-.pi / 30)...(.pi / 30)),
            roll: Float.random(in: (-.pi / 45)...(.pi / 45))
        )
    }
}
