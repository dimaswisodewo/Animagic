//
//  DrawingSessionManager.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 22/07/26.
//

import Observation
import PencilKit

@MainActor
@Observable
final class DrawingSessionManager {
    var drawing = PKDrawing()
    var activeDrawingID: UUID?
    private(set) var pendingARCutoutID: UUID?

    func startNewDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }

    func clearDrawing() {
        startNewDrawing()
    }

    func publishARCutout(_ cutoutID: UUID) {
        pendingARCutoutID = cutoutID
    }

    func consumeARCutout() -> UUID? {
        defer { pendingARCutoutID = nil }
        return pendingARCutoutID
    }

    func clearPendingARCutout() {
        pendingARCutoutID = nil
    }
}
