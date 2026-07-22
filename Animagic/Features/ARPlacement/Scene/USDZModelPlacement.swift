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
        case treeStump
        case treeTrunk
        case fishSchool
        case graniteRock
        case watermelon
        case croissant
        case brocoli
        case cloud
    }

    let id: ID
    let title: String
    let systemImageName: String
    let resourceName: String
    let resourceSubdirectory: String?

    static let all: [Self] = [
        Self(
            id: .birds,
            title: "Birds",
            systemImageName: "bird.fill",
            resourceName: "Birds",
            resourceSubdirectory: nil
        ),
        Self(
            id: .fallingLeaves,
            title: "Falling Leaves",
            systemImageName: "leaf.fill",
            resourceName: "FallingLeaf",
            resourceSubdirectory: nil
        ),
        Self(
            id: .treeStump,
            title: "Tree Stump",
            systemImageName: "tree.fill",
            resourceName: "TreeStump",
            resourceSubdirectory: nil
        ),
        Self(
            id: .treeTrunk,
            title: "Tree Trunk",
            systemImageName: "tree.fill",
            resourceName: "TreeNoLeaf",
            resourceSubdirectory: nil
        ),
        Self(
            id: .watermelon,
            title: "Watermelon",
            systemImageName: "fish.fill",
            resourceName: "WaterMelon",
            resourceSubdirectory: nil
        ),
        Self(
            id: .croissant,
            title: "Croissant",
            systemImageName: "fish.fill",
            resourceName: "Croissant",
            resourceSubdirectory: nil
        ),
        Self(
            id: .brocoli,
            title: "Broccoli",
            systemImageName: "fish.fill",
            resourceName: "Broccoli",
            resourceSubdirectory: nil
        ),
        Self(
            id: .cloud,
            title: "Cloud",
            systemImageName: "fish.fill",
            resourceName: "Cloud",
            resourceSubdirectory: nil
        )
    ]

    static func model(withID id: ID) -> Self? {
        all.first(where: { $0.id == id })
    }
}

enum USDZModelLoadingError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let title): "The \(title) model is missing from the app bundle."
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
    ) {
        self.id = id
        self.anchor = anchor
        catalogID = model.id
        self.supportSurfaceNormal = supportSurfaceNormal

        let root = Entity()
        root.name = "placed_\(model.id.rawValue)"
        interactionRoot = root

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
