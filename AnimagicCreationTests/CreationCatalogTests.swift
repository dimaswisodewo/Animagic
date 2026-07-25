//
//  CreationCatalogTests.swift
//  AniMagicCreationTests
//
//  Created by dimaswisodewo on 25/07/26.
//

import XCTest
@testable import AniMagicCreation

@MainActor
final class CreationCatalogTests: XCTestCase {
    func testSavePublishesCreationAndDelegatesToRepository() throws {
        // Arrange
        let repository = CreationRepositorySpy()
        let catalog = CreationCatalog(repository: repository)
        let creation = Creation(
            title: "Bird",
            source: CreationSource(kind: .drawing, data: Data([1]))
        )

        // Act
        try catalog.save(creation)

        // Assert
        XCTAssertEqual(catalog.creations, [creation])
        XCTAssertEqual(repository.receivedSavedCreations, [creation])
    }

    func testDeleteRemovesCreationAndDelegatesToRepository() throws {
        // Arrange
        let creation = Creation(
            title: "Bird",
            source: CreationSource(kind: .drawing, data: Data([1]))
        )
        let repository = CreationRepositorySpy(creations: [creation])
        let catalog = CreationCatalog(repository: repository)
        catalog.reload()

        // Act
        try catalog.delete(id: creation.id)

        // Assert
        XCTAssertTrue(catalog.creations.isEmpty)
        XCTAssertEqual(repository.receivedDeletedIDs, [creation.id])
    }
}

@MainActor
private final class CreationRepositorySpy: CreationRepository {
    private var creations: [Creation]
    private(set) var receivedSavedCreations: [Creation] = []
    private(set) var receivedDeletedIDs: [CreationID] = []

    init(creations: [Creation] = []) {
        self.creations = creations
    }

    func loadAll() throws -> [Creation] {
        creations
    }

    func save(_ creation: Creation) throws {
        receivedSavedCreations.append(creation)
    }

    func delete(id: CreationID) throws {
        receivedDeletedIDs.append(id)
    }
}
