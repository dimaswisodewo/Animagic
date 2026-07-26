//
//  ARPlacementViewModelTests.swift
//  AniMagicTests
//
//  Created by dimaswisodewo on 26/07/26.
//

import XCTest
@testable import AniMagic

@MainActor
final class ARPlacementViewModelTests: XCTestCase {
    func testCommandAndSelectionTransitions() {
        // Arrange
        let viewModel = ARPlacementViewModel()
        let selection = PlacedObjectSelection(
            objectID: UUID(),
            content: .doodle(.walk),
            elevationMeters: 0
        )
        let requestID = UUID()

        // Act
        viewModel.select(selection)
        viewModel.send(.place(requestID))

        // Assert
        XCTAssertEqual(viewModel.selection, selection)
        XCTAssertEqual(viewModel.sceneCommand, .place(requestID))
    }

    func testReadinessCompletesRequiredRecovery() {
        // Arrange
        let viewModel = ARPlacementViewModel()
        viewModel.requireRecovery()

        // Act
        viewModel.updateReadiness(
            ARTrackingReadiness(isTrackingNormal: true, hasSurface: true)
        )

        // Assert
        XCTAssertFalse(viewModel.recoveryState.showsRecoveryOverlay)
        XCTAssertTrue(viewModel.recoveryState.readiness.allowsInteraction)
    }

    func testRecoveryActionsCanBeRevealedAndRetried() {
        // Arrange
        let viewModel = ARPlacementViewModel()
        viewModel.requireRecovery()

        // Act
        viewModel.revealRecoveryActions()
        let showedActions = viewModel.recoveryState.showsFallbackActions
        viewModel.keepTryingRecovery()

        // Assert
        XCTAssertTrue(showedActions)
        XCTAssertFalse(viewModel.recoveryState.showsFallbackActions)
    }
}
