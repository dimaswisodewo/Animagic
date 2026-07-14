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
    private enum Manipulation: Hashable {
        case translation
        case scale
        case rotation
    }

    private let registry: SceneObjectRegistry
    private var activeManipulations: Set<Manipulation> = []
    private var startingScale: SIMD3<Float>?
    private var startingOrientation: simd_quatf?

    private(set) var selectedObjectID: UUID?
    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)?

    init(registry: SceneObjectRegistry) {
        self.registry = registry
    }

    var selectedObject: PlacedCutout? {
        selectedObjectID.flatMap(registry.object(withID:))
    }

    var selection: PlacedObjectSelection? {
        selectedObject.map {
            PlacedObjectSelection(
                objectID: $0.id,
                animalArchetype: $0.animalArchetype
            )
        }
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
        guard hitBelongsToSelection(hitEntity) else {
            return false
        }
        begin(.translation)
        return true
    }

    func moveSelected(to projection: SurfaceProjection) {
        guard let selectedObject else {
            return
        }
        selectedObject.interactionRoot.setPosition(projection.position, relativeTo: nil)
        selectedObject.supportSurfaceNormal = simd_normalize(projection.normal)
    }

    func endTranslation() {
        end(.translation)
    }

    func beginScale(on hitEntity: Entity?) -> Bool {
        guard hitBelongsToSelection(hitEntity),
              let selectedObject else {
            return false
        }
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
        selectedObject?.setSelected(false)
        selectedObject?.isAnimationPaused = false
        selectedObjectID = objectID
        selectedObject?.setSelected(true)
        activeManipulations.removeAll()
        notifySelectionChanged()
    }

    private func begin(_ manipulation: Manipulation) {
        activeManipulations.insert(manipulation)
        selectedObject?.isAnimationPaused = true
    }

    private func end(_ manipulation: Manipulation) {
        activeManipulations.remove(manipulation)
        if activeManipulations.isEmpty {
            selectedObject?.isAnimationPaused = false
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

    private func notifySelectionChanged() {
        guard let selectedObject else {
            onSelectionChanged?(nil)
            return
        }
        onSelectionChanged?(
            PlacedObjectSelection(
                objectID: selectedObject.id,
                animalArchetype: selectedObject.animalArchetype
            )
        )
    }
}
