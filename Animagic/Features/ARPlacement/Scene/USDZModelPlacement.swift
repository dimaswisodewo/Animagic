//
//  USDZModelPlacement.swift
//  AniMagic
//
//  Created by dimaswisodewo on 15/07/26.
//

import Foundation
import RealityKit
import UIKit

struct PlaceableUSDZModel: Identifiable, Hashable {
    enum ID: String, Hashable {
        case birds
        case fallingLeaves
        case tree
        case fishSchool
    }

    enum Normalization: Hashable {
        case maximumExtent(Float)
        case height(Float)
    }

    let id: ID
    let title: String
    let systemImageName: String
    let resourceName: String
    let resourceSubdirectory: String?
    let normalization: Normalization

    static let all: [Self] = [
        Self(
            id: .birds,
            title: "Birds",
            systemImageName: "bird.fill",
            resourceName: "Birds",
            resourceSubdirectory: nil,
            normalization: .maximumExtent(1.0)
        ),
        Self(
            id: .fallingLeaves,
            title: "Falling Leaves",
            systemImageName: "leaf.fill",
            resourceName: "FallingLeaf",
            resourceSubdirectory: nil,
            normalization: .maximumExtent(0.75)
        ),
        Self(
            id: .tree,
            title: "Tree",
            systemImageName: "tree.fill",
            resourceName: "tree_1",
            resourceSubdirectory: nil,
            normalization: .height(2.0)
        ),
        Self(
            id: .fishSchool,
            title: "Fish School",
            systemImageName: "fish.fill",
            resourceName: "fishs",
            resourceSubdirectory: nil,
            normalization: .maximumExtent(1.0)
        )
    ]

    static func model(withID id: ID) -> Self? {
        all.first(where: { $0.id == id })
    }
}

enum USDZModelLoadingError: LocalizedError {
    case missingResource(String)
    case emptyModel(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let title): "The \(title) model is missing from the app bundle."
        case .emptyModel(let title): "The \(title) model has no visible content."
        }
    }
}

@MainActor
final class USDZModelRepository {
    typealias Completion = (Result<Entity, Error>) -> Void

    private let bundle: Bundle
    private var prototypes: [PlaceableUSDZModel.ID: Entity] = [:]
    private var loadTasks: [PlaceableUSDZModel.ID: Task<Entity, Error>] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadClone(of model: PlaceableUSDZModel, completion: @escaping Completion) {
        if let prototype = prototypes[model.id] {
            Task { @MainActor in
                completion(.success(prototype.clone(recursive: true)))
            }
            return
        }

        guard let url = bundle.url(
            forResource: model.resourceName,
            withExtension: "usdz",
            subdirectory: model.resourceSubdirectory
        ) else {
            Task { @MainActor [weak self] in
                self?.loadTasks.removeValue(forKey: model.id)
                completion(.failure(USDZModelLoadingError.missingResource(model.title)))
            }
            return
        }

        let loadTask: Task<Entity, Error>
        if let existingTask = loadTasks[model.id] {
            loadTask = existingTask
        } else {
            loadTask = Task {
                try await Entity(contentsOf: url)
            }
            loadTasks[model.id] = loadTask
        }

        Task { @MainActor [weak self] in
            do {
                let entity = try await loadTask.value
                self?.prototypes[model.id] = entity
                self?.loadTasks.removeValue(forKey: model.id)
                completion(.success(entity.clone(recursive: true)))
            } catch {
                self?.loadTasks.removeValue(forKey: model.id)
                completion(.failure(error))
            }
        }
    }

    func preload(_ models: [PlaceableUSDZModel] = PlaceableUSDZModel.all) {
        models.forEach { model in
            loadClone(of: model) { _ in }
        }
    }

}

@MainActor
final class PlacedUSDZModel: PlacedSceneObject {
    let id: UUID
    let anchor: AnchorEntity
    let interactionRoot: Entity
    var supportSurfaceNormal: SIMD3<Float>

    private let catalogID: PlaceableUSDZModel.ID
    private var animationController: AnimationPlaybackController?

    var selection: PlacedObjectSelection {
        PlacedObjectSelection(objectID: id, content: .model(catalogID))
    }

    init(
        id: UUID,
        anchor: AnchorEntity,
        model: PlaceableUSDZModel,
        loadedEntity: Entity,
        supportSurfaceNormal: SIMD3<Float>
    ) throws {
        self.id = id
        self.anchor = anchor
        catalogID = model.id
        self.supportSurfaceNormal = supportSurfaceNormal

        let root = Entity()
        root.name = "placed_\(model.id.rawValue)"
        interactionRoot = root

        let visualBounds = loadedEntity.visualBounds(relativeTo: loadedEntity)
        let extents = visualBounds.extents
        let sourceDimension: Float
        switch model.normalization {
        case .maximumExtent:
            sourceDimension = max(extents.x, extents.y, extents.z)
        case .height:
            sourceDimension = extents.y
        }
        guard sourceDimension > 0.0001 else {
            throw USDZModelLoadingError.emptyModel(model.title)
        }

        let targetDimension: Float
        switch model.normalization {
        case .maximumExtent(let target), .height(let target): targetDimension = target
        }
        let scale = targetDimension / sourceDimension
        let center = visualBounds.center
        loadedEntity.scale = SIMD3(repeating: scale)
        loadedEntity.position = [-center.x * scale, -visualBounds.min.y * scale, -center.z * scale]
        loadedEntity.generateCollisionShapes(recursive: true)
        Self.configureInteractionCollisions(in: loadedEntity)
        root.components.set(InteractableComponent(objectID: id))
        root.components.set(InputTargetComponent())
        root.addChild(loadedEntity)

        anchor.addChild(root)
        if let animation = loadedEntity.availableAnimations.first {
            animationController = loadedEntity.playAnimation(animation.repeat())
        }
    }

    func setSelected(_ isSelected: Bool) {
        // No-op (handled by 3D gizmo in the controller)
    }

    private static func configureInteractionCollisions(in entity: Entity) {
        if var collision = entity.components[CollisionComponent.self] {
            collision.filter = CollisionFilter(group: .interactable, mask: .interactable)
            entity.components.set(collision)
        }
        entity.children.forEach(configureInteractionCollisions(in:))
    }
}
