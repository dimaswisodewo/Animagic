//
//  PlaySessionModelTests.swift
//  AniMagicPlayTests
//
//  Created by dimaswisodewo on 25/07/26.
//

import AniMagicPlay
import XCTest

@MainActor
final class PlaySessionModelTests: XCTestCase {
    func testSwitchingEnvironmentPreservesSelectedCreation() {
        // Arrange
        let creationID = UUID()
        let model = PlaySessionModel(
            intent: PlayIntent(
                environment: .augmentedReality,
                initialCreationID: creationID
            )
        )

        // Act
        model.switchEnvironment(to: .virtualRoom)

        // Assert
        XCTAssertEqual(model.intent.environment, .virtualRoom)
        XCTAssertEqual(model.intent.initialCreationID, creationID)
    }

    func testPauseAndResumeUpdateSessionState() {
        // Arrange
        let model = PlaySessionModel(
            intent: PlayIntent(environment: .augmentedReality)
        )

        // Act
        model.pause()

        // Assert
        XCTAssertTrue(model.isPaused)

        // Act
        model.resume()

        // Assert
        XCTAssertFalse(model.isPaused)
    }
}
