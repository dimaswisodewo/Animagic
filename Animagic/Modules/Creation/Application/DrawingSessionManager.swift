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
public final class DrawingSessionManager {
    public var drawing = PKDrawing()
    public var activeDrawingID: UUID?
    public private(set) var pendingARCutoutID: UUID?

    public init() {}

    public func startNewDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }

    public func clearDrawing() {
        startNewDrawing()
    }

    public func publishARCutout(_ cutoutID: UUID) {
        pendingARCutoutID = cutoutID
    }

    public func consumeARCutout() -> UUID? {
        defer { pendingARCutoutID = nil }
        return pendingARCutoutID
    }

    public func clearPendingARCutout() {
        pendingARCutoutID = nil
    }
}
