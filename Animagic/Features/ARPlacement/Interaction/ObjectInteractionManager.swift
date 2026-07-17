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
        static let activeFrequency: Float = 20
        static let settlingFrequency: Float = 14
        static let maximumAcceleration: Float = 90
        static let maximumSpeed: Float = 8
        static let positionTolerance: Float = 0.002
        static let velocityTolerance: Float = 0.01
    }

    private enum Manipulation: Hashable {
        case translation
        case scale
        case rotation
    }

    private struct TranslationState {
        let objectID: UUID
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
            targetPosition: selectedObject.interactionRoot.position(relativeTo: nil)
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

    func endTranslation() {
        translationState?.isGestureActive = false
        end(.translation)
    }

    func update(deltaTime rawDeltaTime: Float) {
        guard var translationState,
              let object = registry.object(withID: translationState.objectID) else {
            self.translationState = nil
            return
        }

        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 30.0)
        guard deltaTime > 0 else { return }

        let currentPosition = object.interactionRoot.position(relativeTo: nil)
        let displacement = translationState.targetPosition - currentPosition
        let frequency = translationState.isGestureActive
            ? TranslationMotion.activeFrequency
            : TranslationMotion.settlingFrequency
        let springAcceleration = displacement * frequency * frequency
            - translationState.velocity * (2 * frequency)
        let acceleration = springAcceleration.limited(
            to: TranslationMotion.maximumAcceleration
        )

        translationState.velocity += acceleration * deltaTime
        translationState.velocity = translationState.velocity.limited(
            to: TranslationMotion.maximumSpeed
        )
        object.interactionRoot.setPosition(
            currentPosition + translationState.velocity * deltaTime,
            relativeTo: nil
        )

        let hasSettled = simd_length(displacement) <= TranslationMotion.positionTolerance
            && simd_length(translationState.velocity) <= TranslationMotion.velocityTolerance
        if !translationState.isGestureActive, hasSettled {
            object.interactionRoot.setPosition(translationState.targetPosition, relativeTo: nil)
            self.translationState = nil
        } else {
            self.translationState = translationState
        }
    }

    func isMovingByDirectManipulation(_ objectID: UUID) -> Bool {
        translationState?.objectID == objectID
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
