//
//  PreviewArtworkRepository.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import Foundation

#if DEBUG
@MainActor
final class PreviewArtworkRepository: ArtworkRepository {
    private var drawings: [SavedDrawing]
    private var cutouts: [CutoutAsset]

    init(drawings: [SavedDrawing] = [], cutouts: [CutoutAsset] = []) {
        self.drawings = drawings
        self.cutouts = cutouts
    }

    func loadSnapshot() throws -> ArtworkSnapshot {
        ArtworkSnapshot(drawings: drawings, cutouts: cutouts)
    }

    func upsertDrawing(_ drawing: SavedDrawing) throws {
        if let index = drawings.firstIndex(where: { $0.id == drawing.id }) {
            drawings[index] = drawing
        } else {
            drawings.append(drawing)
        }
    }

    func upsertDrawings(_ drawings: [SavedDrawing]) throws {
        for drawing in drawings { try upsertDrawing(drawing) }
    }

    func deleteDrawing(id: UUID) throws {
        drawings.removeAll { $0.id == id }
        cutouts.removeAll { $0.sourceDrawingID == id }
    }

    func persistClassifiedCutout(
        drawing: SavedDrawing,
        cutout: CutoutAsset,
        replacingExistingCutouts: Bool
    ) throws {
        try upsertDrawing(drawing)
        if replacingExistingCutouts {
            cutouts.removeAll { $0.sourceDrawingID == drawing.id }
        }
        upsertCutout(cutout)
    }

    func deleteCutout(id: UUID) throws {
        cutouts.removeAll { $0.id == id }
    }

    func deleteAllCutouts() throws {
        cutouts.removeAll()
    }

    func upsertCutouts(_ cutouts: [CutoutAsset]) throws {
        for cutout in cutouts { upsertCutout(cutout) }
    }

    func updateCutout(_ cutout: CutoutAsset, sourceDrawing: SavedDrawing?) throws {
        upsertCutout(cutout)
        if let sourceDrawing { try upsertDrawing(sourceDrawing) }
    }

    private func upsertCutout(_ cutout: CutoutAsset) {
        if let index = cutouts.firstIndex(where: { $0.id == cutout.id }) {
            cutouts[index] = cutout
        } else {
            cutouts.append(cutout)
        }
    }
}
#endif
