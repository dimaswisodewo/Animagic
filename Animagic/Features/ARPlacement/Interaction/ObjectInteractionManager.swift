//
//  ObjectInteractionManager.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import RealityKit

@MainActor
final class ObjectInteractionManager: ObjectInteractionManaging {
    private enum TranslationMotion {
        static let directActiveFrequency: Float = 20
        static let directSettlingFrequency: Float = 14
        static let directMaximumAcceleration: Float = 90
        static let directMaximumSpeed: Float = 8
        static let positionTolerance: Float = 0.002
        static let velocityTolerance: Float = 0.01
    }

    private enum TranslationKind {
        case direct
        case guided
        case precise
    }

    private struct GuidedMotionProfile {
        let frequency: Float
        let maximumAcceleration: Float
        let maximumSpeed: Float
        let turnRate: Float
    }

    private enum Manipulation: Hashable {
        case translation
        case scale
        case rotation
    }

    private struct TranslationState {
        let objectID: UUID
        let kind: TranslationKind
        var targetPosition: SIMD3<Float>
        var velocity = SIMD3<Float>.zero
        var grabOffset: SIMD3<Float>?
        var isGestureActive = true
    }

    private let registry: SceneObjectRegistry
    private var activeManipulations: Set<Manipulation> = []
    private var startingScale: SIMD3<Float>?
    private var startingOrientation: simd_quatf?
    private var translationState: TranslationState?

    private(set) var selectedObjectID: UUID?
    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)?

    init(registry: SceneObjectRegistry) {
        self.registry = registry
    }

    var selectedObject: (any PlacedSceneObject)? {
        selectedObjectID.flatMap(registry.object(withID:))
    }

    var selection: PlacedObjectSelection? {
        selectedObject?.selection
    }

    func handleTap(on hitEntity: Entity?) -> Bool {
        guard let objectID = objectID(containing: hitEntity) else {
            if selectedObjectID != nil {
                select(nil)
                return true
            }
            return false
        }

        select(objectID == selectedObjectID ? nil : objectID)
        return true
    }

    func beginTranslation(on hitEntity: Entity?) -> Bool {
        guard hitBelongsToSelection(hitEntity),
              let selectedObject else {
            return false
        }
        translationState = TranslationState(
            objectID: selectedObject.id,
            kind: .direct,
            targetPosition: selectedObject.interactionRoot.position(relativeTo: nil)
        )
        begin(.translation)
        return true
    }

    func beginGuidedTranslation() -> Bool {
        guard let selectedObject else {
            return false
        }
        let carriedVelocity: SIMD3<Float>
        if let translationState,
           translationState.objectID == selectedObject.id,
           translationState.kind == .guided {
            carriedVelocity = translationState.velocity
        } else {
            carriedVelocity = .zero
        }
        translationState = TranslationState(
            objectID: selectedObject.id,
            kind: .guided,
            targetPosition: selectedObject.interactionRoot.position(relativeTo: nil),
            velocity: carriedVelocity,
            grabOffset: .zero
        )
        return true
    }

    func beginPreciseTranslation(on hitEntity: Entity?) -> Bool {
        guard let objectID = objectID(containing: hitEntity) else {
            return false
        }
        select(objectID)
        guard let selectedObject else {
            return false
        }
        translationState = TranslationState(
            objectID: selectedObject.id,
            kind: .precise,
            targetPosition: selectedObject.interactionRoot.position(relativeTo: nil),
            grabOffset: .zero
        )
        begin(.translation)
        return true
    }

    func moveSelected(to projection: SurfaceProjection) {
        guard let selectedObject,
              var translationState,
              translationState.objectID == selectedObject.id else {
            return
        }

        if translationState.grabOffset == nil {
            translationState.grabOffset =
                selectedObject.interactionRoot.position(relativeTo: nil) - projection.position
        }
        translationState.targetPosition = projection.position + (translationState.grabOffset ?? .zero)
        self.translationState = translationState
        selectedObject.supportSurfaceNormal = simd_normalize(projection.normal)
    }

    func moveSelectedPrecisely(to projection: SurfaceProjection) {
        guard let selectedObject,
              var translationState,
              translationState.objectID == selectedObject.id,
              translationState.kind == .precise else {
            return
        }

        translationState.targetPosition = projection.position
        translationState.velocity = .zero
        self.translationState = translationState
        selectedObject.interactionRoot.setPosition(projection.position, relativeTo: nil)
        selectedObject.supportSurfaceNormal = simd_normalize(projection.normal)
    }

    func endTranslation() {
        let translationKind = translationState?.kind
        translationState?.isGestureActive = false
        if translationKind == .direct || translationKind == .precise {
            end(.translation)
        }
    }

    func update(deltaTime rawDeltaTime: Float) {
        guard var translationState,
              let object = registry.object(withID: translationState.objectID) else {
            self.translationState = nil
            return
        }

        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 30.0)
        guard deltaTime > 0 else { return }

        if translationState.kind == .precise {
            self.translationState = translationState.isGestureActive
                ? translationState
                : nil
            return
        }

        let currentPosition = object.interactionRoot.position(relativeTo: nil)
        let displacement = translationState.targetPosition - currentPosition
        let guidedProfile = guidedMotionProfile(for: object)
        let frequency: Float
        let maximumAcceleration: Float
        let maximumSpeed: Float
        switch translationState.kind {
        case .direct:
            frequency = translationState.isGestureActive
                ? TranslationMotion.directActiveFrequency
                : TranslationMotion.directSettlingFrequency
            maximumAcceleration = TranslationMotion.directMaximumAcceleration
            maximumSpeed = TranslationMotion.directMaximumSpeed
        case .guided:
            frequency = guidedProfile.frequency
            maximumAcceleration = guidedProfile.maximumAcceleration
            maximumSpeed = guidedProfile.maximumSpeed
        case .precise:
            return
        }
        let springAcceleration = displacement * frequency * frequency
            - translationState.velocity * (2 * frequency)
        let acceleration = springAcceleration.limited(
            to: maximumAcceleration
        )

        translationState.velocity += acceleration * deltaTime
        translationState.velocity = translationState.velocity.limited(
            to: maximumSpeed
        )
        object.interactionRoot.setPosition(
            currentPosition + translationState.velocity * deltaTime,
            relativeTo: nil
        )
        if translationState.kind == .guided {
            updateFacingDirection(
                of: object,
                velocity: translationState.velocity,
                turnRate: guidedProfile.turnRate,
                deltaTime: deltaTime
            )
        }

        let hasSettled = simd_length(displacement) <= TranslationMotion.positionTolerance
            && simd_length(translationState.velocity) <= TranslationMotion.velocityTolerance
        if !translationState.isGestureActive, hasSettled {
            object.interactionRoot.setPosition(translationState.targetPosition, relativeTo: nil)
            self.translationState = nil
        } else {
            self.translationState = translationState
        }
    }

    func beginScale(on hitEntity: Entity?) -> Bool {
        guard hitBelongsToSelection(hitEntity),
              let selectedObject else {
            return false
        }
        finishTranslationMotion()
        startingScale = selectedObject.interactionRoot.scale
        begin(.scale)
        return true
    }

    func isBeingTranslated(_ objectID: UUID) -> Bool {
        translationState?.objectID == objectID
    }

    func scaleSelected(by factor: Float) {
        guard let selectedObject, let startingScale else {
            return
        }
        let targetScale = startingScale.x * factor
        let clampedScale = min(max(targetScale, 0.25), 4)
        selectedObject.interactionRoot.scale = [clampedScale, clampedScale, clampedScale]
    }

    func endScale() {
        startingScale = nil
        end(.scale)
    }

    func beginRotation(on hitEntity: Entity?) -> Bool {
        guard hitBelongsToSelection(hitEntity),
              let selectedObject else {
            return false
        }
        finishTranslationMotion()
        startingOrientation = selectedObject.interactionRoot.orientation(relativeTo: nil)
        begin(.rotation)
        return true
    }

    func rotateSelected(by angle: Float) {
        guard let selectedObject, let startingOrientation else {
            return
        }
        let axis = simd_normalize(selectedObject.supportSurfaceNormal)
        let rotation = simd_quatf(angle: angle, axis: axis)
        selectedObject.interactionRoot.setOrientation(
            rotation * startingOrientation,
            relativeTo: nil
        )
    }

    func endRotation() {
        startingOrientation = nil
        end(.rotation)
    }

    func setSelectedAnimalArchetype(_ archetype: AnimalArchetype) {
        guard let selectedObject else {
            return
        }
        selectedObject.setAnimalArchetype(archetype)
        notifySelectionChanged()
    }

    func deleteSelected() {
        guard let selectedObjectID,
              let object = registry.remove(id: selectedObjectID) else {
            return
        }
        translationState = nil
        object.anchor.removeFromParent()
        object.setSelected(false)
        self.selectedObjectID = nil
        activeManipulations.removeAll()
        notifySelectionChanged()
    }

    func clearSelection() {
        select(nil)
    }

    private func select(_ objectID: UUID?) {
        guard objectID != selectedObjectID else {
            return
        }
        finishTranslationMotion()
        selectedObject?.setSelected(false)
        selectedObject?.setInteractionPaused(false)
        selectedObjectID = objectID
        selectedObject?.setSelected(true)
        activeManipulations.removeAll()
        notifySelectionChanged()
    }

    private func begin(_ manipulation: Manipulation) {
        activeManipulations.insert(manipulation)
        selectedObject?.setInteractionPaused(true)
    }

    private func end(_ manipulation: Manipulation) {
        activeManipulations.remove(manipulation)
        if activeManipulations.isEmpty {
            selectedObject?.setInteractionPaused(false)
        }
    }

    private func hitBelongsToSelection(_ entity: Entity?) -> Bool {
        guard let selectedObjectID else {
            return false
        }
        return objectID(containing: entity) == selectedObjectID
    }

    private func objectID(containing entity: Entity?) -> UUID? {
        var currentEntity = entity
        while let current = currentEntity {
            if let component = current.components[InteractableComponent.self] {
                return component.objectID
            }
            currentEntity = current.parent
        }
        return nil
    }

    private func finishTranslationMotion() {
        guard let translationState,
              let object = registry.object(withID: translationState.objectID) else {
            self.translationState = nil
            return
        }
        object.interactionRoot.setPosition(translationState.targetPosition, relativeTo: nil)
        self.translationState = nil
    }

    private func guidedMotionProfile(
        for object: any PlacedSceneObject
    ) -> GuidedMotionProfile {
        guard case .doodle(let archetype) = object.selection.content else {
            return GuidedMotionProfile(
                frequency: 4.8,
                maximumAcceleration: 2.1,
                maximumSpeed: 0.72,
                turnRate: 5
            )
        }

        return switch archetype {
        case .fish:
            GuidedMotionProfile(
                frequency: 5.5,
                maximumAcceleration: 2.6,
                maximumSpeed: 0.95,
                turnRate: 6
            )
        case .bird:
            GuidedMotionProfile(
                frequency: 6.5,
                maximumAcceleration: 3.8,
                maximumSpeed: 1.2,
                turnRate: 7.5
            )
        case .butterfly:
            GuidedMotionProfile(
                frequency: 5.8,
                maximumAcceleration: 2.3,
                maximumSpeed: 0.82,
                turnRate: 8.5
            )
        case .cat:
            GuidedMotionProfile(
                frequency: 7,
                maximumAcceleration: 4.2,
                maximumSpeed: 1.05,
                turnRate: 9
            )
        case .cow:
            GuidedMotionProfile(
                frequency: 3.8,
                maximumAcceleration: 1.35,
                maximumSpeed: 0.55,
                turnRate: 3.6
            )
        case .rabbit:
            GuidedMotionProfile(
                frequency: 7.5,
                maximumAcceleration: 5.2,
                maximumSpeed: 1.25,
                turnRate: 10
            )
        case .snake:
            GuidedMotionProfile(
                frequency: 4.2,
                maximumAcceleration: 1.8,
                maximumSpeed: 0.7,
                turnRate: 4.5
            )
        case .crab:
            GuidedMotionProfile(
                frequency: 5,
                maximumAcceleration: 2,
                maximumSpeed: 0.62,
                turnRate: 5.5
            )
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

    private func notifySelectionChanged() {
        guard let selectedObject else {
            onSelectionChanged?(nil)
            return
        }
        onSelectionChanged?(selectedObject.selection)
    }
}

private extension SIMD3 where Scalar == Float {
    func limited(to maximumLength: Float) -> Self {
        let length = simd_length(self)
        guard length > maximumLength, length > 0 else { return self }
        return self / length * maximumLength
    }
}
