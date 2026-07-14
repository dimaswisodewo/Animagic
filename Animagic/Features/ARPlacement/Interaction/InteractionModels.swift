//
//  InteractionModels.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import RealityKit

struct InteractableComponent: Component {
    let objectID: UUID
}

struct PlacedObjectSelection: Equatable {
    let objectID: UUID
    let animalArchetype: AnimalArchetype
}

struct SurfaceProjection {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}

extension CollisionGroup {
    static let interactable = CollisionGroup(rawValue: 1 << 10)
}

@MainActor
protocol ObjectInteractionManaging: AnyObject {
    var selectedObject: PlacedCutout? { get }
    var selection: PlacedObjectSelection? { get }
    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)? { get set }

    func handleTap(on hitEntity: Entity?) -> Bool
    func beginTranslation(on hitEntity: Entity?) -> Bool
    func moveSelected(to projection: SurfaceProjection)
    func endTranslation()
    func beginScale(on hitEntity: Entity?) -> Bool
    func scaleSelected(by factor: Float)
    func endScale()
    func beginRotation(on hitEntity: Entity?) -> Bool
    func rotateSelected(by angle: Float)
    func endRotation()
    func setSelectedAnimalArchetype(_ archetype: AnimalArchetype)
    func deleteSelected()
    func clearSelection()
}

@MainActor
protocol SceneEditing: AnyObject {
    var placedObjectSelection: PlacedObjectSelection? { get }
    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype)
    func deleteSelectedObject()
}
