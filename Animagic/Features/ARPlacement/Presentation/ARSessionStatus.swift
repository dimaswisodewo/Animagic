//
//  ARSessionStatus.swift
//  Animagic
//
//  Created by MorpKnight on 17/07/26.
//

import Foundation

enum ARSessionStatus: Equatable {
    case searching
    case ready
    case noSurface
    case unsupported
    case cameraDenied
    case failed
    case retrying

    var isBlockingOverlay: Bool {
        switch self {
        case .unsupported, .cameraDenied, .failed, .retrying:
            true
        case .searching, .ready, .noSurface:
            false
        }
    }

    var allowsRetry: Bool {
        switch self {
        case .cameraDenied, .failed:
            true
        case .searching, .ready, .noSurface, .unsupported, .retrying:
            false
        }
    }

    var offersSettings: Bool {
        self == .cameraDenied
    }

    var title: String {
        switch self {
        case .searching:
            "Looking for a surface"
        case .ready:
            "Ready to place"
        case .noSurface:
            "No surface found"
        case .unsupported:
            "AR isn’t available"
        case .cameraDenied:
            "Camera access is needed"
        case .failed:
            "AR needs another try"
        case .retrying:
            "Restarting AR…"
        }
    }

    var message: String {
        switch self {
        case .searching:
            "Move the device slowly to find a floor or table."
        case .ready:
            "Aim the reticle, then tap Place."
        case .noSurface:
            "Try pointing at a floor or table."
        case .unsupported:
            "This device doesn’t support the AR experience."
        case .cameraDenied:
            "Allow camera access in Settings, then return here and retry AR."
        case .failed:
            "The camera session stopped unexpectedly."
        case .retrying:
            "Preparing the camera and surface detection."
        }
    }

    var systemImageName: String {
        switch self {
        case .searching:
            "viewfinder"
        case .ready:
            "checkmark.circle.fill"
        case .noSurface:
            "square.dashed"
        case .unsupported:
            "exclamationmark.triangle.fill"
        case .cameraDenied:
            "camera.fill"
        case .failed:
            "arrow.clockwise.circle.fill"
        case .retrying:
            "arrow.triangle.2.circlepath"
        }
    }
}
