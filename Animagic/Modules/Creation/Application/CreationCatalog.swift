//
//  CreationCatalog.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Observation

@MainActor
@Observable
public final class CreationCatalog {
    public private(set) var creations: [Creation] = []
    public private(set) var lastErrorDescription: String?

    @ObservationIgnored
    private let repository: any CreationRepository

    public var summaries: [CreationSummary] {
        creations.map(CreationSummary.init)
    }

    public var playableCreations: [PlayableCreation] {
        creations.compactMap(PlayableCreation.init)
    }

    public init(repository: any CreationRepository) {
        self.repository = repository
    }

    public func reload() {
        do {
            creations = try repository.loadAll()
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    public func save(_ creation: Creation) throws {
        try repository.save(creation)
        if let index = creations.firstIndex(where: { $0.id == creation.id }) {
            creations[index] = creation
        } else {
            creations.append(creation)
        }
        lastErrorDescription = nil
    }

    public func delete(id: CreationID) throws {
        try repository.delete(id: id)
        creations.removeAll { $0.id == id }
        lastErrorDescription = nil
    }
}
