//
//  ARPlacementViewModel.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import Foundation
import Observation

enum ARPlacementSceneCommand: Equatable {
    case place(UUID)
    case clearSelection(UUID)
    case delete(UUID)
    case flipFacing(UUID)
    case undoDelete(UUID)
    case discardUndo(UUID)
    case cancelPencilInteraction(UUID)
    case capturePhoto(UUID)
}

@MainActor
@Observable
final class ARPlacementViewModel {
    var sceneCommand: ARPlacementSceneCommand?
    var selection: PlacedObjectSelection?
    private(set) var recoveryState = ARReturnRecoveryState()

    func send(_ command: ARPlacementSceneCommand) {
        sceneCommand = command
    }

    func select(_ selection: PlacedObjectSelection?) {
        self.selection = selection
    }

    func updateReadiness(_ readiness: ARTrackingReadiness) {
        recoveryState.updateReadiness(readiness)
    }

    func requireRecovery() {
        recoveryState.requireRecovery()
    }

    func keepTryingRecovery() {
        recoveryState.keepTrying()
    }

    func revealRecoveryActions() {
        recoveryState.revealFallbackActions()
    }
}
