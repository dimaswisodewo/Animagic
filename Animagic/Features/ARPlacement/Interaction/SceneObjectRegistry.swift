//
//  SceneObjectRegistry.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation

@MainActor
final class SceneObjectRegistry {
    private var objectsByID: [UUID: PlacedCutout] = [:]

    var objects: [PlacedCutout] {
        Array(objectsByID.values)
    }

    var isEmpty: Bool { objectsByID.isEmpty }

    func forEach(_ body: (PlacedCutout) -> Void) {
        objectsByID.values.forEach(body)
    }

    func register(_ object: PlacedCutout) {
        objectsByID[object.id] = object
    }

    func object(withID id: UUID) -> PlacedCutout? {
        objectsByID[id]
    }

    @discardableResult
    func remove(id: UUID) -> PlacedCutout? {
        objectsByID.removeValue(forKey: id)
    }

    func removeAll() {
        objectsByID.removeAll()
    }
}
