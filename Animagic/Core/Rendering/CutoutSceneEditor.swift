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
    private struct GroupMotionProfile {
        let maximumSpeed: Float
        let maximumAcceleration: Float
        let responseRate: Float
        let turnRate: Float
        let baseDelay: Float
    }

    private struct GroupMotionState {
        var velocity = SIMD3<Float>.zero
        var formationOffset = SIMD3<Float>.zero
        var responseDelay: Float = 0
        var elapsed: Float = 0
    }

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
    
    var hoverTargetPosition: SIMD3<Float>?

    private let entityFactory: CutoutEntityFactory
    private let modelRepository: USDZModelRepository
    private let registry: SceneObjectRegistry
    private let interactionManager: ObjectInteractionManager
    private var interactionAdapter: ARViewInteractionAdapter?
    private weak var arView: ARView?
    private let configuration: CutoutSceneConfiguration
    private var simulationAccumulator: Float = 0
    private var isLoadingModel = false
    private var groupMotionStates: [UUID: GroupMotionState] = [:]
    private var formationObjectIDs: [UUID] = []
    private var isGroupMotionActive = false

    var objectCount: Int { registry.objects.count }
    var maximumObjectCount: Int? { configuration.maximumObjectCount }

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedSpawnMode: SpawnMode,
        selectedContentType: PlacementContentType = .doodle,
        selectedModelID: PlaceableUSDZModel.ID? = PlaceableUSDZModel.all.first?.id,
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
        self.selectedModelID = selectedModelID
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

        let motionDeltaTime = min(max(deltaTime, 0), 1.0 / 30.0)
        interactionManager.update(deltaTime: motionDeltaTime)
        updateGroupMotion(deltaTime: motionDeltaTime)
        
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

    private func updateGroupMotion(deltaTime: Float) {
        let objects = registry.objects.sorted { $0.id.uuidString < $1.id.uuidString }
        let objectIDs = objects.map(\.id)
        let objectIDSet = Set(objectIDs)
        groupMotionStates = groupMotionStates.filter { objectIDSet.contains($0.key) }

        guard let target = hoverTargetPosition else {
            isGroupMotionActive = false
            formationObjectIDs.removeAll()
            settleGroupMotion(objects: objects, deltaTime: deltaTime)
            return
        }

        if !isGroupMotionActive || formationObjectIDs != objectIDs {
            configureFormation(for: objects)
            isGroupMotionActive = true
            formationObjectIDs = objectIDs
        }

        let positions = Dictionary(uniqueKeysWithValues: objects.map {
            ($0.id, $0.interactionRoot.position(relativeTo: nil))
        })
        let scale = sceneMotionScale
        let separationRadius = formationSpacing * 0.9

        for object in objects {
            guard !interactionManager.isMovingByDirectManipulation(object.id),
                  var state = groupMotionStates[object.id],
                  let currentPosition = positions[object.id] else {
                groupMotionStates[object.id]?.velocity = .zero
                continue
            }

            state.elapsed += deltaTime
            guard state.elapsed >= state.responseDelay else {
                groupMotionStates[object.id] = state
                continue
            }

            let profile = motionProfile(for: object)
            let targetPosition = target + state.formationOffset
            let displacement = targetPosition - currentPosition
            let distance = simd_length(displacement)
            let arrivalRadius = max(formationSpacing * 0.3, 0.045 * scale)
            let slowdownRadius = max(arrivalRadius * 4.5, profile.maximumSpeed * scale * 0.55)
            let speedRatio = easedUnit(distance / slowdownRadius)
            let desiredSpeed = distance <= arrivalRadius * 0.2
                ? 0
                : profile.maximumSpeed * scale * speedRatio
            let desiredVelocity = normalized(displacement) * desiredSpeed
            var acceleration = (desiredVelocity - state.velocity) * profile.responseRate
            acceleration += separationAcceleration(
                for: object.id,
                at: currentPosition,
                positions: positions,
                radius: separationRadius,
                strength: profile.maximumAcceleration * scale * 0.8
            )
            acceleration = limited(
                acceleration,
                to: profile.maximumAcceleration * scale
            )

            state.velocity += acceleration * deltaTime
            state.velocity = limited(
                state.velocity,
                to: profile.maximumSpeed * scale
            )
            if distance <= arrivalRadius {
                state.velocity *= exp(-5.5 * deltaTime)
            }

            object.interactionRoot.setPosition(
                currentPosition + state.velocity * deltaTime,
                relativeTo: nil
            )
            updateFacingDirection(
                of: object,
                velocity: state.velocity,
                turnRate: profile.turnRate,
                deltaTime: deltaTime
            )
            groupMotionStates[object.id] = state
        }
    }

    private func configureFormation(for objects: [any PlacedSceneObject]) {
        let goldenAngle = Float.pi * (3 - sqrt(Float(5)))
        for (index, object) in objects.enumerated() {
            var state = groupMotionStates[object.id] ?? GroupMotionState()
            let slot = Float(index)
            let radius = index == 0 ? 0 : formationSpacing * sqrt(slot)
            let angle = goldenAngle * slot
            state.formationOffset = [cos(angle) * radius, 0, sin(angle) * radius]
            state.responseDelay = motionProfile(for: object).baseDelay
                + Float(index % 4) * 0.025
            state.elapsed = 0
            groupMotionStates[object.id] = state
        }
    }

    private func settleGroupMotion(
        objects: [any PlacedSceneObject],
        deltaTime: Float
    ) {
        for object in objects {
            guard !interactionManager.isMovingByDirectManipulation(object.id),
                  var state = groupMotionStates[object.id] else {
                continue
            }

            state.velocity *= exp(-9 * deltaTime)
            if simd_length_squared(state.velocity) < 0.000004 {
                state.velocity = .zero
            } else {
                let currentPosition = object.interactionRoot.position(relativeTo: nil)
                object.interactionRoot.setPosition(
                    currentPosition + state.velocity * deltaTime,
                    relativeTo: nil
                )
            }
            groupMotionStates[object.id] = state
        }
    }

    private func separationAcceleration(
        for objectID: UUID,
        at position: SIMD3<Float>,
        positions: [UUID: SIMD3<Float>],
        radius: Float,
        strength: Float
    ) -> SIMD3<Float> {
        positions.reduce(into: SIMD3<Float>.zero) { result, entry in
            guard entry.key != objectID else { return }
            var offset = position - entry.value
            offset.y = 0
            let distance = simd_length(offset)
            guard distance > 0.0001, distance < radius else { return }
            result += offset / distance * (1 - distance / radius) * strength
        }
    }

    private func updateFacingDirection(
        of object: any PlacedSceneObject,
        velocity: SIMD3<Float>,
        turnRate: Float,
        deltaTime: Float
    ) {
        var horizontalVelocity = velocity
        horizontalVelocity.y = 0
        guard simd_length_squared(horizontalVelocity) > 0.0001 else { return }

        let targetYaw = atan2(horizontalVelocity.x, horizontalVelocity.z)
        let blend = 1 - exp(-turnRate * deltaTime)
        object.interactionRoot.setOrientation(
            simd_slerp(
                object.interactionRoot.orientation(relativeTo: nil),
                simd_quatf(angle: targetYaw, axis: [0, 1, 0]),
                blend
            ),
            relativeTo: nil
        )
    }

    private func motionProfile(for object: any PlacedSceneObject) -> GroupMotionProfile {
        guard case .doodle(let archetype) = object.selection.content else {
            return GroupMotionProfile(
                maximumSpeed: 0.72,
                maximumAcceleration: 2.1,
                responseRate: 4.8,
                turnRate: 5,
                baseDelay: 0.06
            )
        }

        return switch archetype {
        case .fish:
            GroupMotionProfile(
                maximumSpeed: 0.95,
                maximumAcceleration: 2.6,
                responseRate: 5.5,
                turnRate: 6,
                baseDelay: 0.03
            )
        case .bird:
            GroupMotionProfile(
                maximumSpeed: 1.2,
                maximumAcceleration: 3.8,
                responseRate: 6.5,
                turnRate: 7.5,
                baseDelay: 0.04
            )
        case .butterfly:
            GroupMotionProfile(
                maximumSpeed: 0.82,
                maximumAcceleration: 2.3,
                responseRate: 5.8,
                turnRate: 8.5,
                baseDelay: 0.12
            )
        case .cat:
            GroupMotionProfile(
                maximumSpeed: 1.05,
                maximumAcceleration: 4.2,
                responseRate: 7,
                turnRate: 9,
                baseDelay: 0.03
            )
        case .cow:
            GroupMotionProfile(
                maximumSpeed: 0.55,
                maximumAcceleration: 1.35,
                responseRate: 3.8,
                turnRate: 3.6,
                baseDelay: 0.12
            )
        case .rabbit:
            GroupMotionProfile(
                maximumSpeed: 1.25,
                maximumAcceleration: 5.2,
                responseRate: 7.5,
                turnRate: 10,
                baseDelay: 0.08
            )
        case .snake:
            GroupMotionProfile(
                maximumSpeed: 0.7,
                maximumAcceleration: 1.8,
                responseRate: 4.2,
                turnRate: 4.5,
                baseDelay: 0.1
            )
        case .crab:
            GroupMotionProfile(
                maximumSpeed: 0.62,
                maximumAcceleration: 2,
                responseRate: 5,
                turnRate: 5.5,
                baseDelay: 0.08
            )
        }
    }

    private var sceneMotionScale: Float {
        max((configuration.physicalWidthOverride ?? 0.25) / 0.25, 1)
    }

    private var formationSpacing: Float {
        max((configuration.physicalWidthOverride ?? 0.24) * 0.9, 0.18)
    }

    private func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        simd_length_squared(vector) > 0.000001 ? simd_normalize(vector) : .zero
    }

    private func limited(_ vector: SIMD3<Float>, to maximumLength: Float) -> SIMD3<Float> {
        let length = simd_length(vector)
        guard length > maximumLength, length > 0 else { return vector }
        return vector / length * maximumLength
    }

    private func easedUnit(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    var placedObjectSelection: PlacedObjectSelection? {
        interactionManager.selection
    }

    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype) {
        interactionManager.setSelectedAnimalArchetype(archetype)
    }

    func deleteSelectedObject() {
        interactionManager.deleteSelected()
    }
    
    func triggerLoveAnimation() {
        registry.forEach { $0.showLove() }
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
