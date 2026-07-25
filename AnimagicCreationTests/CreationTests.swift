//
//  CreationTests.swift
//  AniMagicCreationTests
//
//  Created by dimaswisodewo on 25/07/26.
//

import XCTest
@testable import AniMagicCreation

final class CreationTests: XCTestCase {
    func testCreationBecomesPlayableWhenAssetExists() {
        // Arrange
        let source = CreationSource(kind: .drawing, data: Data([1]))
        let asset = PlayableAsset(
            imageData: Data([2]),
            pixelWidth: 100,
            pixelHeight: 80
        )

        // Act
        let creation = Creation(
            title: "Bird",
            source: source,
            playableAsset: asset
        )

        // Assert
        XCTAssertTrue(creation.isPlayable)
        XCTAssertNotNil(PlayableCreation(creation))
    }

    func testCreationWithoutAssetIsNotPlayable() {
        // Arrange
        let source = CreationSource(kind: .photo, data: Data([1]))

        // Act
        let creation = Creation(title: "Photo", source: source)

        // Assert
        XCTAssertFalse(creation.isPlayable)
        XCTAssertNil(PlayableCreation(creation))
    }

    func testHabitatUsesOverrideInsteadOfPrediction() {
        // Arrange
        let source = CreationSource(kind: .drawing, data: Data([1]))
        let assessment = SpeciesAssessment(
            prediction: SpeciesPrediction(label: "fish", confidence: 0.99),
            overrideLabel: "bird"
        )

        // Act
        let creation = Creation(
            title: "Animal",
            source: source,
            speciesAssessment: assessment
        )

        // Assert
        XCTAssertEqual(creation.habitat, .skies)
    }
}
