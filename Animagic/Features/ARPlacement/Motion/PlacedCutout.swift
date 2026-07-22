//
//  PlacedCutout.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import RealityKit

@MainActor
final class PlacedCutout: PlacedSceneObject {
    let id: UUID
    let anchor: AnchorEntity
    let interactionRoot: Entity
    let animatedRoot: Entity
    private let shadowEntity: ModelEntity?
    private let frontEntity: ModelEntity
    private let backEntity: ModelEntity
    private let spawnMode: SpawnMode
    private let initialYaw: Float
    private let initialRoll: Float
    private let physicalWidth: Float
    private let bodyStyle: AnimalBodyStyle
    private var configuration: MotionInstanceConfiguration
    private var simulator: MotionSimulator
    private var previousSample: MotionSample?
    private var transitionSample: MotionSample?
    private var transitionElapsed: Float = 1
    private var lastMaterialLocomotion: AnimalLocomotion?
    private var lastMaterialBehavior: AnimalBehavior?
    private var facingOverride: Float = 1
    private let meshes: [CutoutRenderQuality: MeshResource]
    private var renderQuality: CutoutRenderQuality = .balanced
    private var isSelected = false
    private var viewerDistance: Float = 1.5
    private(set) var animalLocomotion: AnimalLocomotion
    var isAnimationPaused = false
    var supportSurfaceNormal: SIMD3<Float>

    var selection: PlacedObjectSelection {
        PlacedObjectSelection(
            objectID: id,
            content: .doodle(animalLocomotion),
            elevationMeters: elevationMeters
        )
    }

    init(
        id: UUID,
        anchor: AnchorEntity,
        parts: CutoutEntityParts,
        locomotion: AnimalLocomotion,
        spawnMode: SpawnMode,
        initialYaw: Float = 0,
        initialRoll: Float = 0,
        supportSurfaceNormal: SIMD3<Float> = [0, 1, 0]
    ) {
        self.id = id
        self.anchor = anchor
        interactionRoot = parts.root
        animatedRoot = parts.body
        shadowEntity = parts.shadow
        frontEntity = parts.front
        backEntity = parts.back
        self.spawnMode = spawnMode
        self.initialYaw = initialYaw
        self.initialRoll = initialRoll
        physicalWidth = parts.physicalSize.x
        bodyStyle = parts.bodyStyle
        meshes = parts.meshes
        facingOverride = parts.defaultFacing
        animalLocomotion = locomotion
        self.supportSurfaceNormal = supportSurfaceNormal

        let configuration = MotionInstanceConfiguration.make(
            for: locomotion,
            spawnMode: spawnMode,
            physicalWidth: parts.physicalSize.x
        )
        self.configuration = configuration
        simulator = MotionSimulator(yaw: initialYaw, configuration: configuration)

        var initialPosition = interactionRoot.position(relativeTo: anchor)
        initialPosition.y += configuration.baseAltitude
        interactionRoot.setPosition(initialPosition, relativeTo: anchor)
    }

    func update(deltaTime: Float) {
        guard !isAnimationPaused else { return }
        var sample = simulator.update(
            deltaTime: deltaTime,
            locomotion: animalLocomotion,
            configuration: configuration,
            initialYaw: initialYaw
        )
        if let transitionSample, transitionElapsed < 0.5 {
            transitionElapsed += min(deltaTime, 1.0 / 15.0)
            sample = blend(
                from: transitionSample,
                to: sample,
                amount: smoothstep(transitionElapsed / 0.5)
            )
        }
        apply(sample)
        previousSample = sample
    }

    func setSelected(_ isSelected: Bool) {
        self.isSelected = isSelected
        setViewerDistance(viewerDistance)
    }

    func setInteractionPaused(_ isPaused: Bool) {
        isAnimationPaused = isPaused
    }

    func setAnimalLocomotion(_ locomotion: AnimalLocomotion) {
        guard locomotion != animalLocomotion else { return }
        transitionElapsed = 0
        animalLocomotion = locomotion
        lastMaterialLocomotion = nil

        let previousConfiguration = configuration
        let nextConfiguration = MotionInstanceConfiguration.make(
            for: locomotion,
            spawnMode: spawnMode,
            physicalWidth: physicalWidth
        )
        let altitudeRebase = nextConfiguration.baseAltitude - previousConfiguration.baseAltitude
        var rebasedTransitionSample = previousSample
        rebasedTransitionSample?.position.y += altitudeRebase
        transitionSample = rebasedTransitionSample
        configuration = nextConfiguration

        let previousYaw = previousSample?.yaw ?? initialYaw
        let yawOffset = atan2(sin(previousYaw - initialYaw), cos(previousYaw - initialYaw))
        let currentDirection: Float = abs(yawOffset) > .pi / 2 ? -1 : 1
        var rebasedPosition = previousSample?.position ?? animatedRoot.position
        if previousSample == nil {
            rebasedPosition.y += previousConfiguration.baseAltitude
        }
        rebasedPosition.y += altitudeRebase
        simulator = MotionSimulator(
            position: rebasedPosition,
            yaw: previousYaw,
            configuration: nextConfiguration,
            initialLaneDirection: -currentDirection
        )
    }

    func receiveMotionStimulus(_ stimulus: AnimalMotionStimulus) {
        simulator.receive(stimulus)
    }

    func flipFacing() {
        facingOverride *= -1
        lastMaterialLocomotion = nil
    }

    func setViewerDistance(_ distance: Float) {
        viewerDistance = distance
        let quality: CutoutRenderQuality = isSelected ? .hero : distance < 1.1 ? .hero : distance < 2.2 ? .balanced : .economy
        applyRenderQuality(quality)
    }

    private func applyRenderQuality(_ quality: CutoutRenderQuality) {
        guard quality != renderQuality, let mesh = meshes[quality] else { return }
        renderQuality = quality
        for entity in [frontEntity, backEntity] {
            guard var model = entity.model else { continue }
            model.mesh = mesh
            entity.model = model
        }
    }

    private func apply(_ sample: MotionSample) {
        var relativePosition = sample.position
        relativePosition.y -= configuration.baseAltitude
        let interactionScale = max(abs(interactionRoot.scale.y), 0.001)
        relativePosition.y = max(relativePosition.y, -elevationMeters / interactionScale)
        animatedRoot.position = relativePosition
        animatedRoot.orientation = simd_quatf(angle: sample.yaw, axis: [0, 1, 0])
            * simd_quatf(angle: sample.pitch, axis: [1, 0, 0])
            * simd_quatf(angle: sample.roll + initialRoll, axis: [0, 0, 1])
        animatedRoot.scale = [sample.scaleX, sample.scaleY, 1]
        updateShadow(for: sample)
        updateDeformationMaterialIfNeeded(sample)
    }

    private func updateShadow(for sample: MotionSample) {
        guard let shadowEntity else { return }
        let referenceHeight = max(
            configuration.baseAltitude + configuration.verticalAmplitude,
            0.12
        )
        let relativeAltitude = sample.position.y - configuration.baseAltitude
        let interactionScale = max(abs(interactionRoot.scale.y), 0.001)
        let visibleAltitude = max(elevationMeters + relativeAltitude * interactionScale, 0)
        let height = min(visibleAltitude / referenceHeight, 1)
        let easedHeight = height * height * (3 - 2 * height)
        let spread = 1 + easedHeight * 0.65
        let shadowHeight = (0.002 - elevationMeters) / interactionScale
        shadowEntity.position = [sample.position.x, shadowHeight, sample.position.z]
        shadowEntity.orientation = simd_quatf(angle: sample.yaw, axis: [0, 1, 0])
            * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        shadowEntity.scale = [sample.scaleX * spread, spread, 1]
        shadowEntity.components[OpacityComponent.self]?.opacity = 1 - easedHeight * 0.78
    }

    private func updateDeformationMaterialIfNeeded(_ sample: MotionSample) {
        lastMaterialLocomotion = animalLocomotion
        lastMaterialBehavior = sample.behavior
        updateDeformationMaterial(on: frontEntity, sample: sample, faceDirection: 1)
        updateDeformationMaterial(on: backEntity, sample: sample, faceDirection: -1)
    }

    private func updateDeformationMaterial(
        on entity: ModelEntity,
        sample: MotionSample,
        faceDirection: Float
    ) {
        guard var model = entity.model,
              var material = model.materials.first as? CustomMaterial else { return }
        material.custom.value = [
            bodyStyle.shaderIndex
                + animalLocomotion.shaderIndex * 0.01
                + Float(sample.behavior.rawValue) * 0.0001,
            min(sample.deformationActivity + sample.attention * 0.35, 1.25),
            sample.deformationPhase,
            faceDirection * facingOverride
        ]
        model.materials = [material]
        entity.model = model
    }
}

extension AnimalLocomotion {
    var shaderIndex: Float {
        switch self {
        case .swim: 0
        case .fly: 1
        case .flutter: 2
        case .walk: 3
        case .stomp: 4
        case .hop: 5
        case .slither: 6
        case .scuttle: 7
        case .crawl: 8
        case .waddle: 9
        case .generic: 10
        }
    }
}
