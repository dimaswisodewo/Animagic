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

enum PlacementContentType: String, CaseIterable, Identifiable {
    case doodle
    case model

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doodle: "Doodles"
        case .model: "3D Models"
        }
    }
}

enum PlacedObjectContent: Equatable {
    case doodle(AnimalArchetype)
    case model(PlaceableUSDZModel.ID)

    var animalArchetype: AnimalArchetype? {
        guard case .doodle(let archetype) = self else { return nil }
        return archetype
    }

    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .model(let modelID): PlaceableUSDZModel.model(withID: modelID)?.title ?? "3D Model"
        }
    }
}

struct PlacedObjectSelection: Equatable {
    let objectID: UUID
    let content: PlacedObjectContent

    var animalArchetype: AnimalArchetype? { content.animalArchetype }
    var title: String { content.title }
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
    var selectedObject: (any PlacedSceneObject)? { get }
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
protocol PlacedSceneObject: AnyObject {
    var id: UUID { get }
    var anchor: AnchorEntity { get }
    var interactionRoot: Entity { get }
    var supportSurfaceNormal: SIMD3<Float> { get set }
    var selection: PlacedObjectSelection { get }

    func update(deltaTime: Float)
    func setSelected(_ isSelected: Bool)
    func setInteractionPaused(_ isPaused: Bool)
    func setAnimalArchetype(_ archetype: AnimalArchetype)
    func showLove()
}

extension PlacedSceneObject {
    func update(deltaTime: Float) {}
    func setInteractionPaused(_ isPaused: Bool) {}
    func setAnimalArchetype(_ archetype: AnimalArchetype) {}
    
    func showLove() {
        // Use a standard unicode heart glyph which is guaranteed to generate a 3D path mesh,
        // unlike emojis which often fail in MeshResource.generateText.
        let mesh = MeshResource.generateText("♥", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.2))
        let material = SimpleMaterial(color: .systemPink, isMetallic: false)
        let heart = ModelEntity(mesh: mesh, materials: [material])
        
        // Center the text horizontally (Text mesh originates at bottom-left)
        let bounds = heart.visualBounds(relativeTo: nil)
        heart.position = [-(bounds.extents.x / 2.0), 0.4, 0] // Centered above object
        
        interactionRoot.addChild(heart)
        
        var transform = heart.transform
        transform.translation.y += 0.3
        transform.scale = [1.2, 1.2, 1.2]
        
        heart.move(to: transform, relativeTo: heart.parent, duration: 1.0, timingFunction: .easeOut)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            heart.removeFromParent()
        }
    }
}

@MainActor
protocol SceneEditing: AnyObject {
    var placedObjectSelection: PlacedObjectSelection? { get }
    var hoverTargetPosition: SIMD3<Float>? { get set }
    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype)
    func deleteSelectedObject()
}
