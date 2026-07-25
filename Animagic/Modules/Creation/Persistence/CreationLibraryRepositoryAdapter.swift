//
//  CreationLibraryRepositoryAdapter.swift
//  AniMagic
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation
import PencilKit
import SwiftData
import UIKit

@MainActor
final class CreationLibraryRepositoryAdapter: CreationLibraryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        context.autosaveEnabled = false
    }

    func loadSnapshot() throws -> CreationLibrarySnapshot {
        do {
            let records = try context.fetch(
                FetchDescriptor<CreationRecord>(
                    sortBy: [SortDescriptor(\CreationRecord.createdAt, order: .reverse)]
                )
            )
            return CreationLibrarySnapshot(
                drawings: records.compactMap(Self.drawing),
                cutouts: records.compactMap(Self.cutout)
            )
        } catch {
            throw wrap(error, operation: "load your creations")
        }
    }

    func upsertDrawing(_ drawing: CreationDrawing) throws {
        try perform(operation: "save the drawing") {
            try upsertDrawingRecord(drawing)
        }
    }

    func upsertDrawings(_ drawings: [CreationDrawing]) throws {
        guard !drawings.isEmpty else { return }
        try perform(operation: "update drawing names") {
            for drawing in drawings {
                try upsertDrawingRecord(drawing)
            }
        }
    }

    func deleteDrawing(id: UUID) throws {
        try perform(operation: "delete the drawing") {
            if let record = try creationRecord(id: id) {
                context.delete(record)
            }
        }
    }

    func persistClassifiedCutout(
        drawing: CreationDrawing,
        cutout: CreationPlayableAsset,
        replacingExistingCutouts: Bool
    ) throws {
        try perform(operation: "save the recognized drawing") {
            let record = try drawingRecord(for: drawing)
            try apply(cutout, to: record)
        }
    }

    func deleteCutout(id: UUID) throws {
        try perform(operation: "delete the cutout") {
            guard let record = try recordContainingAsset(id: id) else { return }
            if record.sourceKindRawValue == CreationSourceKind.legacyProcessedImage.rawValue {
                context.delete(record)
            } else {
                clearPlayableAsset(on: record)
            }
        }
    }

    func deleteAllCutouts() throws {
        try perform(operation: "clear playable assets") {
            for record in try context.fetch(FetchDescriptor<CreationRecord>()) {
                if record.sourceKindRawValue == CreationSourceKind.legacyProcessedImage.rawValue {
                    context.delete(record)
                } else {
                    clearPlayableAsset(on: record)
                }
            }
        }
    }

    func upsertCutouts(_ cutouts: [CreationPlayableAsset]) throws {
        guard !cutouts.isEmpty else { return }
        try perform(operation: "save the playable assets") {
            for cutout in cutouts {
                try upsertCutout(cutout)
            }
        }
    }

    func updateCutout(_ cutout: CreationPlayableAsset, sourceDrawing: CreationDrawing?) throws {
        try perform(operation: "update the playable asset") {
            if let sourceDrawing {
                let record = try drawingRecord(for: sourceDrawing)
                try apply(cutout, to: record)
            } else {
                try upsertCutout(cutout)
            }
        }
    }

    private func upsertDrawingRecord(_ drawing: CreationDrawing) throws {
        _ = try drawingRecord(for: drawing)
    }

    private func drawingRecord(for drawing: CreationDrawing) throws -> CreationRecord {
        if let record = try creationRecord(id: drawing.id) {
            record.title = drawing.name
            record.sourceKindRawValue = CreationSourceKind.drawing.rawValue
            record.sourceData = drawing.drawing.dataRepresentation()
            record.sourceMediaType = "com.apple.pencilkit.drawing"
            record.predictedLabel = drawing.doodleClassification?.label
            record.predictionConfidence = drawing.doodleClassification.map {
                Double($0.confidence)
            }
            record.overrideLabel = drawing.doodleOverrideLabel
            record.isTitleManuallyEdited = drawing.isNameManuallyEdited
            record.createdAt = drawing.createdAt
            return record
        }

        let record = CreationRecord(
            id: drawing.id,
            title: drawing.name,
            sourceKind: .drawing,
            sourceData: drawing.drawing.dataRepresentation(),
            sourceMediaType: "com.apple.pencilkit.drawing",
            predictedLabel: drawing.doodleClassification?.label,
            predictionConfidence: drawing.doodleClassification.map {
                Double($0.confidence)
            },
            overrideLabel: drawing.doodleOverrideLabel,
            isTitleManuallyEdited: drawing.isNameManuallyEdited,
            createdAt: drawing.createdAt
        )
        context.insert(record)
        return record
    }

    private func upsertCutout(_ cutout: CreationPlayableAsset) throws {
        guard let imageData = cutout.pngData else {
            throw CreationCompatibilityError.invalidImageData
        }

        if let sourceDrawingID = cutout.sourceDrawingID,
           let record = try creationRecord(id: sourceDrawingID) {
            try apply(cutout, imageData: imageData, to: record)
            return
        }
        if let record = try recordContainingAsset(id: cutout.id) {
            try apply(cutout, imageData: imageData, to: record)
            return
        }

        context.insert(
            CreationRecord(
                id: cutout.id,
                title: Self.displayTitle(for: cutout),
                sourceKind: .legacyProcessedImage,
                sourceData: imageData,
                sourceMediaType: "public.png",
                playableAssetID: cutout.id,
                playableImageData: imageData,
                playablePixelWidth: cutout.originalSize.width,
                playablePixelHeight: cutout.originalSize.height,
                predictedLabel: cutout.doodleClassification?.label,
                predictionConfidence: cutout.doodleClassification.map {
                    Double($0.confidence)
                },
                classificationError: cutout.doodleClassificationError,
                overrideLabel: cutout.doodleOverrideLabel
            )
        )
    }

    private func apply(_ cutout: CreationPlayableAsset, to record: CreationRecord) throws {
        guard let imageData = cutout.pngData else {
            throw CreationCompatibilityError.invalidImageData
        }
        try apply(cutout, imageData: imageData, to: record)
    }

    private func apply(
        _ cutout: CreationPlayableAsset,
        imageData: Data,
        to record: CreationRecord
    ) throws {
        record.playableAssetID = cutout.id
        record.playableImageData = imageData
        record.playablePixelWidth = cutout.originalSize.width
        record.playablePixelHeight = cutout.originalSize.height
        record.predictedLabel = cutout.doodleClassification?.label
        record.predictionConfidence = cutout.doodleClassification.map {
            Double($0.confidence)
        }
        record.classificationError = cutout.doodleClassificationError
        record.overrideLabel = cutout.doodleOverrideLabel
    }

    private func clearPlayableAsset(on record: CreationRecord) {
        record.playableAssetID = nil
        record.playableImageData = nil
        record.playablePixelWidth = nil
        record.playablePixelHeight = nil
        record.classificationError = nil
    }

    private func creationRecord(id: UUID) throws -> CreationRecord? {
        let creationID = id
        var descriptor = FetchDescriptor<CreationRecord>(
            predicate: #Predicate { $0.id == creationID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func recordContainingAsset(id: UUID) throws -> CreationRecord? {
        let assetID = id
        var descriptor = FetchDescriptor<CreationRecord>(
            predicate: #Predicate { $0.playableAssetID == assetID }
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
        if let error = error as? ArtworkRepositoryError {
            return error
        }
        return ArtworkRepositoryError(operation: operation, underlyingError: error)
    }

    private static func drawing(from record: CreationRecord) -> CreationDrawing? {
        guard record.sourceKindRawValue == CreationSourceKind.drawing.rawValue,
              let drawing = try? PKDrawing(data: record.sourceData) else {
            return nil
        }
        return CreationDrawing(
            id: record.id,
            name: record.title,
            drawing: drawing,
            category: CreationCategory.category(
                forDoodleLabel: record.overrideLabel ?? record.predictedLabel
            ),
            doodleClassification: record.predictedLabel.map {
                DoodleClassification(
                    label: $0,
                    confidence: Float(record.predictionConfidence ?? 0)
                )
            },
            doodleOverrideLabel: record.overrideLabel,
            isNameManuallyEdited: record.isTitleManuallyEdited,
            createdAt: record.createdAt
        )
    }

    private static func cutout(from record: CreationRecord) -> CreationPlayableAsset? {
        guard let assetID = record.playableAssetID,
              let data = record.playableImageData,
              let image = UIImage(data: data) else {
            return nil
        }
        let sourceDrawingID = record.sourceKindRawValue == CreationSourceKind.drawing.rawValue
            ? record.id
            : nil
        return CreationPlayableAsset(
            id: assetID,
            sourceDrawingID: sourceDrawingID,
            image: image,
            originalSize: CGSize(
                width: record.playablePixelWidth ?? Double(image.size.width),
                height: record.playablePixelHeight ?? Double(image.size.height)
            ),
            doodleClassification: record.predictedLabel.map {
                DoodleClassification(
                    label: $0,
                    confidence: Float(record.predictionConfidence ?? 0)
                )
            },
            doodleClassificationError: record.classificationError,
            doodleOverrideLabel: record.overrideLabel
        )
    }

    private static func displayTitle(for cutout: CreationPlayableAsset) -> String {
        cutout.doodleOverrideLabel?.capitalized
            ?? cutout.doodleClassification?.label.capitalized
            ?? "Photo Cutout"
    }
}

private enum CreationCompatibilityError: Error {
    case invalidImageData
}
