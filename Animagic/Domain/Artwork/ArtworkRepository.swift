//
//  ArtworkRepository.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import Foundation

@MainActor
protocol ArtworkRepository {
    func loadSnapshot() throws -> ArtworkSnapshot
    func upsertDrawing(_ drawing: SavedDrawing) throws
    func upsertDrawings(_ drawings: [SavedDrawing]) throws
    func deleteDrawing(id: UUID) throws
    func persistClassifiedCutout(
        drawing: SavedDrawing,
        cutout: CutoutAsset,
        replacingExistingCutouts: Bool
    ) throws
    func deleteCutout(id: UUID) throws
    func deleteAllCutouts() throws
    func upsertCutouts(_ cutouts: [CutoutAsset]) throws
    func updateCutout(_ cutout: CutoutAsset, sourceDrawing: SavedDrawing?) throws
}

struct ArtworkRepositoryError: LocalizedError {
    let operation: String
    let underlyingError: Error

    var errorDescription: String? {
        "Couldn’t \(operation). Your previous data is unchanged."
    }
}
