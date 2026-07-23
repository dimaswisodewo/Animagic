import Foundation
import SwiftData

@MainActor
protocol ArtworkRepository {
    func loadSnapshot() throws -> ArtworkSnapshot
    func upsertDrawing(_ drawing: SavedDrawing) throws
    func upsertDrawings(_ drawings: [SavedDrawing]) throws
    /// Deletes the drawing and every cutout derived from it in one transaction.
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

@MainActor
final class SwiftDataArtworkRepository: ArtworkRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        context.autosaveEnabled = false
    }

    func loadSnapshot() throws -> ArtworkSnapshot {
        do {
            let drawings = try context.fetch(
                FetchDescriptor<SavedDrawingRecord>(
                    sortBy: [SortDescriptor(\SavedDrawingRecord.createdAt, order: .reverse)]
                )
            )
            let cutouts = try context.fetch(FetchDescriptor<CutoutAssetRecord>())
            return ArtworkSnapshot(
                drawings: drawings.compactMap { $0.asValue() },
                cutouts: cutouts.compactMap { $0.asValue() }
            )
        } catch {
            throw wrap(error, operation: "load your artwork")
        }
    }

    func upsertDrawing(_ drawing: SavedDrawing) throws {
        try perform(operation: "save the drawing") {
            try upsertDrawingRecord(drawing)
        }
    }

    func upsertDrawings(_ drawings: [SavedDrawing]) throws {
        guard !drawings.isEmpty else { return }
        try perform(operation: "update drawing names") {
            for drawing in drawings {
                try upsertDrawingRecord(drawing)
            }
        }
    }

    func deleteDrawing(id: UUID) throws {
        try perform(operation: "delete the drawing") {
            let drawingID = id
            let cutoutDescriptor = FetchDescriptor<CutoutAssetRecord>(
                predicate: #Predicate { $0.sourceDrawingID == drawingID }
            )
            for cutoutRecord in try context.fetch(cutoutDescriptor) {
                context.delete(cutoutRecord)
            }
            if let record = try drawingRecord(id: id) {
                context.delete(record)
            }
        }
    }

    func persistClassifiedCutout(
        drawing: SavedDrawing,
        cutout: CutoutAsset,
        replacingExistingCutouts: Bool
    ) throws {
        try perform(operation: "save the recognized drawing") {
            try upsertDrawingRecord(drawing)
            if replacingExistingCutouts {
                let sourceDrawingID = drawing.id
                let descriptor = FetchDescriptor<CutoutAssetRecord>(
                    predicate: #Predicate { $0.sourceDrawingID == sourceDrawingID }
                )
                for record in try context.fetch(descriptor) {
                    context.delete(record)
                }
            }
            try upsertCutoutRecord(cutout)
        }
    }

    func deleteCutout(id: UUID) throws {
        try perform(operation: "delete the cutout") {
            if let record = try cutoutRecord(id: id) {
                context.delete(record)
            }
        }
    }

    func deleteAllCutouts() throws {
        try perform(operation: "clear the cutout library") {
            for record in try context.fetch(FetchDescriptor<CutoutAssetRecord>()) {
                context.delete(record)
            }
        }
    }

    func upsertCutouts(_ cutouts: [CutoutAsset]) throws {
        guard !cutouts.isEmpty else { return }
        try perform(operation: "save the cutouts") {
            for cutout in cutouts {
                try upsertCutoutRecord(cutout)
            }
        }
    }

    func updateCutout(_ cutout: CutoutAsset, sourceDrawing: SavedDrawing?) throws {
        try perform(operation: "update the cutout") {
            try upsertCutoutRecord(cutout)
            if let sourceDrawing {
                try upsertDrawingRecord(sourceDrawing)
            }
        }
    }

    private func upsertDrawingRecord(_ drawing: SavedDrawing) throws {
        if let record = try drawingRecord(id: drawing.id) {
            record.update(from: drawing)
        } else {
            context.insert(SavedDrawingRecord(drawing))
        }
    }

    private func upsertCutoutRecord(_ cutout: CutoutAsset) throws {
        guard let newRecord = CutoutAssetRecord(cutout) else {
            throw CutoutEncodingError.invalidImageData
        }
        if let record = try cutoutRecord(id: cutout.id) {
            record.update(from: newRecord)
        } else {
            context.insert(newRecord)
        }
    }

    private func drawingRecord(id: UUID) throws -> SavedDrawingRecord? {
        let drawingID = id
        var descriptor = FetchDescriptor<SavedDrawingRecord>(
            predicate: #Predicate { $0.id == drawingID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func cutoutRecord(id: UUID) throws -> CutoutAssetRecord? {
        let cutoutID = id
        var descriptor = FetchDescriptor<CutoutAssetRecord>(
            predicate: #Predicate { $0.id == cutoutID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func perform(operation: String, changes: () throws -> Void) throws {
        do {
            try changes()
            if context.hasChanges {
                try context.save()
            }
        } catch {
            context.rollback()
            throw wrap(error, operation: operation)
        }
    }

    private func wrap(_ error: Error, operation: String) -> ArtworkRepositoryError {
        if let repositoryError = error as? ArtworkRepositoryError {
            return repositoryError
        }
        return ArtworkRepositoryError(operation: operation, underlyingError: error)
    }
}

private enum CutoutEncodingError: Error {
    case invalidImageData
}
