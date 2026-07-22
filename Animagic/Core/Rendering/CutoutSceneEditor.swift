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

    static let augmentedReality = Self(physicalWidthOverride: nil, simulationInterval: nil, maximumObjectCount: 20, showsShadow: false)
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
    private(set) var cutoutAssets: [CutoutAsset]
    var selectedCutoutID: CutoutAsset.ID?
    var selectedAnimalLocomotion: AnimalLocomotion
    var selectedSpawnMode: SpawnMode
    var selectedContentType: PlacementContentType
    var selectedModelID: PlaceableUSDZModel.ID?
    var onPlacementResult: ((CutoutPlacementResult) -> Void)?
    var onObjectPlaced: ((any PlacedSceneObject) -> Void)?

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
    var objects: [any PlacedSceneObject] { registry.objects }

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalLocomotion: AnimalLocomotion,
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
        self.selectedAnimalLocomotion = selectedAnimalLocomotion
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

    @discardableResult
    func updateCutoutAssets(_ assets: [CutoutAsset]) -> Set<UUID> {
        cutoutAssets = assets
        let availableAssetIDs = Set(assets.map(\.id))
        let unavailableObjects = registry.objects.compactMap { object -> PlacedCutout? in
            guard let cutout = object as? PlacedCutout,
                  !availableAssetIDs.contains(cutout.cutoutAssetID) else { return nil }
            return cutout
        }
        let removedObjectIDs = Set(unavailableObjects.map(\.id))

        if let selectedObjectID = interactionManager.selectedObject?.id,
           removedObjectIDs.contains(selectedObjectID) {
            interactionManager.clearSelection()
        }
        for object in unavailableObjects {
            object.anchor.removeFromParent()
            registry.remove(id: object.id)
        }
        return removedObjectIDs
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
    func placeSharedObject(
        id: UUID,
        content: PlacedObjectContent,
        cutoutAsset: CutoutAsset?,
        at transform: simd_float4x4,
        interactionTransform: Transform,
        supportSurfaceNormal: SIMD3<Float>
    ) -> CutoutPlacementResult {
        guard registry.object(withID: id) == nil else { return .placed }
        guard objectCount < (configuration.maximumObjectCount ?? .max) else {
            return .limitReached(configuration.maximumObjectCount ?? .max)
        }

        switch content {
        case .doodle(let locomotion):
            return placeCutout(
                at: transform,
                cameraTransform: nil,
                spawnMode: .plane,
                supportSurfaceNormal: supportSurfaceNormal,
                objectID: id,
                cutoutAsset: cutoutAsset,
                locomotion: locomotion,
                interactionTransform: interactionTransform,
                selectsObject: false
            )
        case .model(let modelID):
            return placeModel(
                at: transform,
                supportSurfaceNormal: supportSurfaceNormal,
                objectID: id,
                modelID: modelID,
                interactionTransform: interactionTransform,
                selectsObject: false
            )
        }
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
        deliverCameraProximityStimuli()
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

    private func deliverCameraProximityStimuli() {
        guard let cameraPosition = arView?.cameraTransform.translation else { return }
        registry.forEach { object in
            let objectPosition = object.animatedWorldPosition
            let distance = simd_distance(cameraPosition, objectPosition)
            object.setViewerDistance(distance)
            if distance < 1.2 {
                object.receiveMotionStimulus(.proximity(distance))
            }
        }
    }

    var placedObjectSelection: PlacedObjectSelection? {
        interactionManager.selection
    }

    var selectedObject: (any PlacedSceneObject)? {
        interactionManager.selectedObject
    }

    func object(containing entity: Entity?) -> (any PlacedSceneObject)? {
        interactionManager.object(containing: entity)
    }

    func selectObject(withID id: UUID) {
        interactionManager.selectObject(withID: id)
    }

    func handleTap(on entity: Entity?) -> Bool {
        interactionManager.handleTap(on: entity)
    }

    func beginSelectedObjectElevationAdjustment(for objectID: UUID) {
        interactionManager.beginElevationAdjustment(for: objectID)
    }

    func setSelectedObjectElevationMeters(_ elevationMeters: Float, for objectID: UUID) {
        interactionManager.setElevationMeters(elevationMeters, for: objectID)
    }

    func endSelectedObjectElevationAdjustment(for objectID: UUID) {
        interactionManager.endElevationAdjustment(for: objectID)
    }

    func setSelectedObjectAnimalLocomotion(_ locomotion: AnimalLocomotion) {
        interactionManager.setSelectedAnimalLocomotion(locomotion)
    }

    func flipSelectedObjectAnimalFacing() {
        interactionManager.flipSelectedAnimalFacing()
    }

    @discardableResult
    func deleteSelectedObject() -> DeletedSceneObject? {
        interactionManager.deleteSelected()
    }

    func restoreDeletedObject(_ deletedObject: DeletedSceneObject) {
        guard let arView else { return }
        arView.scene.addAnchor(deletedObject.object.anchor)
        interactionManager.restore(deletedObject)
    }

    func clearSelection() {
        interactionManager.clearSelection()
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
        supportSurfaceNormal: SIMD3<Float>,
        objectID: UUID = UUID(),
        interactionTransform: Transform? = nil,
        selectsObject: Bool = true
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
                supportSurfaceNormal: supportSurfaceNormal,
                objectID: objectID,
                cutoutAsset: selectedCutoutAsset,
                locomotion: selectedAnimalLocomotion,
                interactionTransform: interactionTransform,
                selectsObject: selectsObject
            )
        case .model:
            return placeModel(
                at: transform,
                supportSurfaceNormal: supportSurfaceNormal,
                objectID: objectID,
                modelID: selectedModelID,
                interactionTransform: interactionTransform,
                selectsObject: selectsObject
            )
        }
    }

    private func placeCutout(
        at transform: simd_float4x4,
        cameraTransform: simd_float4x4?,
        spawnMode: SpawnMode,
        supportSurfaceNormal: SIMD3<Float>,
        objectID: UUID,
        cutoutAsset: CutoutAsset?,
        locomotion: AnimalLocomotion,
        interactionTransform: Transform?,
        selectsObject: Bool
    ) -> CutoutPlacementResult {
        guard let cutoutAsset else {
            return .missingAsset
        }
        guard let cutout = try? entityFactory.makeEntity(
                  from: cutoutAsset,
                  locomotion: locomotion,
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
        let placedCutout = PlacedCutout(
                id: objectID,
                cutoutAssetID: cutoutAsset.id,
                anchor: anchor,
                parts: cutout,
                assetID: cutoutAsset.id,
                locomotion: locomotion,
                spawnMode: spawnMode,
                initialYaw: spawnOrientation.yaw,
                initialRoll: spawnOrientation.roll,
                supportSurfaceNormal: simd_normalize(supportSurfaceNormal)
            )
        if let interactionTransform {
            placedCutout.interactionRoot.transform = interactionTransform
        }
        registry.register(placedCutout)
        onObjectPlaced?(placedCutout)
        if selectsObject {
            interactionManager.selectObject(withID: objectID)
        }
        return .placed
    }

    private func placeModel(
        at transform: simd_float4x4,
        supportSurfaceNormal: SIMD3<Float>,
        objectID: UUID,
        modelID: PlaceableUSDZModel.ID?,
        interactionTransform: Transform?,
        selectsObject: Bool
    ) -> CutoutPlacementResult {
        guard !isLoadingModel else {
            return .loading("Loading model…")
        }
        guard let modelID,
              let model = PlaceableUSDZModel.model(withID: modelID) else {
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
                let anchor = AnchorEntity(world: transform)
                let placedModel = PlacedUSDZModel(
                    id: objectID,
                    anchor: anchor,
                    model: model,
                    loadedEntity: loadedEntity,
                    supportSurfaceNormal: simd_normalize(supportSurfaceNormal)
                )
                if let interactionTransform {
                    placedModel.interactionRoot.transform = interactionTransform
                } else {
                    placedModel.interactionRoot.orientation = simd_quatf(
                        angle: Float.random(in: (-.pi / 30)...(.pi / 30)),
                        axis: [0, 1, 0]
                    )
                }
                arView.scene.addAnchor(anchor)
                self.registry.register(placedModel)
                self.onObjectPlaced?(placedModel)
                if selectsObject {
                    self.interactionManager.selectObject(withID: objectID)
                }
                self.onPlacementResult?(.placed)
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
