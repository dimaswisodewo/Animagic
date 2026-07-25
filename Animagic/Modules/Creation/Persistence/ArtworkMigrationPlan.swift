//
//  ArtworkMigrationPlan.swift
//  AniMagic
//
//  Created by dimaswisodewo on 25/07/26.
//

import AniMagicCreation
import Foundation
import SwiftData

enum ArtworkSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SavedDrawingRecord.self, CutoutAssetRecord.self]
    }
}

enum ArtworkBridgeSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] {
        [SavedDrawingRecord.self, CutoutAssetRecord.self, CreationRecord.self]
    }
}

enum ArtworkSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CreationRecord.self]
    }
}

enum ArtworkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ArtworkSchemaV1.self, ArtworkBridgeSchema.self, ArtworkSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: ArtworkSchemaV1.self,
                toVersion: ArtworkBridgeSchema.self,
                willMigrate: nil,
                didMigrate: migrateLegacyArtwork
            ),
            .lightweight(
                fromVersion: ArtworkBridgeSchema.self,
                toVersion: ArtworkSchemaV2.self
            )
        ]
    }

    private static func migrateLegacyArtwork(context: ModelContext) throws {
        if try context.fetchCount(FetchDescriptor<CreationRecord>()) > 0 {
            return
        }

        let drawings = try context.fetch(FetchDescriptor<SavedDrawingRecord>())
        let cutouts = try context.fetch(FetchDescriptor<CutoutAssetRecord>())
        let drawingIDs = Set(drawings.map(\.id))
        let groupedCutouts = Dictionary(grouping: cutouts.compactMap { cutout in
            cutout.sourceDrawingID.map { ($0, cutout) }
        }, by: \.0)
        var consumedCutoutIDs = Set<UUID>()

        for drawing in drawings {
            let linkedCutout = groupedCutouts[drawing.id]?
                .map(\.1)
                .sorted { $0.id.uuidString < $1.id.uuidString }
                .first
            if let linkedCutout {
                consumedCutoutIDs.insert(linkedCutout.id)
            }

            context.insert(
                CreationRecord(
                    id: drawing.id,
                    title: drawing.name,
                    sourceKind: .drawing,
                    sourceData: drawing.drawingData,
                    sourceMediaType: "com.apple.pencilkit.drawing",
                    playableAssetID: linkedCutout?.id,
                    playableImageData: linkedCutout?.imageData,
                    playablePixelWidth: linkedCutout?.originalWidth,
                    playablePixelHeight: linkedCutout?.originalHeight,
                    predictedLabel: linkedCutout?.predictedLabel ?? drawing.predictedLabel,
                    predictionConfidence: linkedCutout?.predictionConfidence
                        ?? drawing.predictionConfidence,
                    classificationError: linkedCutout?.classificationError,
                    overrideLabel: linkedCutout?.overrideLabel ?? drawing.overrideLabel,
                    isTitleManuallyEdited: drawing.isNameManuallyEdited,
                    createdAt: drawing.createdAt
                )
            )
        }

        for cutout in cutouts where !consumedCutoutIDs.contains(cutout.id) {
            let isOrphanedDrawingCutout = cutout.sourceDrawingID.map {
                drawingIDs.contains($0)
            } ?? false
            let title = cutout.overrideLabel
                ?? cutout.predictedLabel
                ?? (isOrphanedDrawingCutout ? "Recovered Creation" : "Photo Cutout")
            context.insert(
                CreationRecord(
                    id: cutout.id,
                    title: title.capitalized,
                    sourceKind: .legacyProcessedImage,
                    sourceData: cutout.imageData,
                    sourceMediaType: "public.png",
                    playableAssetID: cutout.id,
                    playableImageData: cutout.imageData,
                    playablePixelWidth: cutout.originalWidth,
                    playablePixelHeight: cutout.originalHeight,
                    predictedLabel: cutout.predictedLabel,
                    predictionConfidence: cutout.predictionConfidence,
                    classificationError: cutout.classificationError,
                    overrideLabel: cutout.overrideLabel,
                    createdAt: .now
                )
            )
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
