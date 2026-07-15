//
//  SceneObjectRegistry.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation

@MainActor
final class SceneObjectRegistry {
    private var objectsByID: [UUID: any PlacedSceneObject] = [:]

    var objects: [any PlacedSceneObject] {
        Array(objectsByID.values)
    }

    var isEmpty: Bool { objectsByID.isEmpty }

    func forEach(_ body: (any PlacedSceneObject) -> Void) {
        objectsByID.values.forEach(body)
    }

    func register(_ object: any PlacedSceneObject) {
        objectsByID[object.id] = object
    }

    func object(withID id: UUID) -> (any PlacedSceneObject)? {
        objectsByID[id]
    }

    @discardableResult
    func remove(id: UUID) -> (any PlacedSceneObject)? {
        objectsByID.removeValue(forKey: id)
    }

    func removeAll() {
        objectsByID.removeAll()
    }
}
