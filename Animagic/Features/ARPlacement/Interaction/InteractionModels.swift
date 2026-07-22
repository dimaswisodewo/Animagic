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
    case doodle(AnimalLocomotion)
    case model(PlaceableUSDZModel.ID)

    var animalLocomotion: AnimalLocomotion? {
        guard case .doodle(let locomotion) = self else { return nil }
        return locomotion
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
    let elevationMeters: Float

    var animalLocomotion: AnimalLocomotion? { content.animalLocomotion }
    var title: String { content.title }
}

struct SurfaceProjection {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}

enum ARObjectElevation {
    static let range: ClosedRange<Float> = 0...2
    static let groundingThreshold: Float = 0.05
}

/// Retains the exact RealityKit object removed from a scene so deletion can be undone.
@MainActor
final class DeletedSceneObject {
    let object: any PlacedSceneObject

    init(object: any PlacedSceneObject) {
        self.object = object
    }
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
    func beginElevationAdjustment(for objectID: UUID)
    func setElevationMeters(_ elevationMeters: Float, for objectID: UUID)
    func endElevationAdjustment(for objectID: UUID)
    func setSelectedAnimalLocomotion(_ locomotion: AnimalLocomotion)
    @discardableResult
    func deleteSelected() -> DeletedSceneObject?
    func restore(_ deletedObject: DeletedSceneObject)
    func selectObject(withID id: UUID)
    func object(containing entity: Entity?) -> (any PlacedSceneObject)?
    func clearSelection()
}

@MainActor
protocol PlacedSceneObject: AnyObject {
    var id: UUID { get }
    var anchor: AnchorEntity { get }
    var interactionRoot: Entity { get }
    var supportSurfaceNormal: SIMD3<Float> { get set }
    var selection: PlacedObjectSelection { get }
    var sharedCutoutAssetID: CutoutAsset.ID? { get }
    var animatedWorldPosition: SIMD3<Float> { get }
    var elevationMeters: Float { get }

    func update(deltaTime: Float)
    func setSelected(_ isSelected: Bool)
    func setInteractionPaused(_ isPaused: Bool)
    func setAnimalLocomotion(_ locomotion: AnimalLocomotion)
    func receiveMotionStimulus(_ stimulus: AnimalMotionStimulus)
    func flipFacing()
    func setViewerDistance(_ distance: Float)
    func setElevationMeters(_ elevationMeters: Float)
}

extension PlacedSceneObject {
    var sharedCutoutAssetID: CutoutAsset.ID? { nil }
    var animatedWorldPosition: SIMD3<Float> { interactionRoot.position(relativeTo: nil) }
    var elevationMeters: Float { interactionRoot.position(relativeTo: anchor).y }
    func update(deltaTime: Float) {}
    func setInteractionPaused(_ isPaused: Bool) {}
    func setAnimalLocomotion(_ locomotion: AnimalLocomotion) {}
    func receiveMotionStimulus(_ stimulus: AnimalMotionStimulus) {}
    func flipFacing() {}
    func setViewerDistance(_ distance: Float) {}
    func setElevationMeters(_ elevationMeters: Float) {
        var position = interactionRoot.position(relativeTo: anchor)
        position.y = elevationMeters
        interactionRoot.setPosition(position, relativeTo: anchor)
    }
}

@MainActor
protocol SceneEditing: AnyObject {
    var placedObjectSelection: PlacedObjectSelection? { get }
    func beginSelectedObjectElevationAdjustment(for objectID: UUID)
    func setSelectedObjectElevationMeters(_ elevationMeters: Float, for objectID: UUID)
    func endSelectedObjectElevationAdjustment(for objectID: UUID)
    func setSelectedObjectAnimalLocomotion(_ locomotion: AnimalLocomotion)
    func flipSelectedObjectAnimalFacing()
    @discardableResult
    func deleteSelectedObject() -> DeletedSceneObject?
    func restoreDeletedObject(_ deletedObject: DeletedSceneObject)
    func clearSelection()
}
