//
//  ArtworkPolicyTests.swift
//  AniMagicTests
//
//  Created by dimaswisodewo on 26/07/26.
//

import PencilKit
import XCTest
@testable import AniMagic

final class ArtworkPolicyTests: XCTestCase {
    func testAutomaticNameSkipsExistingCaseInsensitiveSequence() {
        // Arrange
        let currentID = UUID()
        let drawings = [
            SavedDrawing(name: "Cat #1", drawing: PKDrawing()),
            SavedDrawing(name: "cat #2", drawing: PKDrawing())
        ]

        // Act
        let name = DrawingNameGenerator.automaticName(
            for: "cat",
            excluding: currentID,
            in: drawings
        )

        // Assert
        XCTAssertEqual(name, "Cat #3")
    }

    func testPlaceholderRecognizesWhitespaceAndUntitled() {
        // Arrange
        let names = ["", "   ", "UNTITLED"]

        // Act
        let results = names.map(DrawingNameGenerator.isPlaceholder)

        // Assert
        XCTAssertEqual(results, [true, true, true])
    }

    func testDrawingOrderingUsesDisplayNameThenCreationDate() {
        // Arrange
        let later = SavedDrawing(
            name: "Bird",
            drawing: PKDrawing(),
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let earlier = SavedDrawing(
            name: "Bird",
            drawing: PKDrawing(),
            createdAt: Date(timeIntervalSince1970: 1)
        )

        // Act
        let drawings = ArtworkLibraryPresentation.sortedDrawings([later, earlier])

        // Assert
        XCTAssertEqual(drawings.map(\.id), [earlier.id, later.id])
    }
}
