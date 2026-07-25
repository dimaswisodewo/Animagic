//
//  ArtworkMigrationPlanTests.swift
//  AniMagicCreationTests
//
//  Created by dimaswisodewo on 25/07/26.
//

import PencilKit
import SwiftData
import UIKit
import XCTest
@testable import AniMagicCreation

@MainActor
final class ArtworkMigrationPlanTests: XCTestCase {
    func testMigrationPreservesDrawingAndLinkedPlayableAsset() throws {
        // Arrange
        let storeURL = temporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }
        let drawingID = UUID()
        let assetID = UUID()
        let drawing = CreationDrawing(
            id: drawingID,
            name: "Bird",
            drawing: PKDrawing(),
            doodleClassification: DoodleClassification(label: "bird", confidence: 0.8),
            isNameManuallyEdited: true,
            createdAt: Date(timeIntervalSince1970: 42)
        )
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 3)).image {
            UIColor.red.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 2, height: 3))
        }
        let cutout = CreationPlayableAsset(
            id: assetID,
            sourceDrawingID: drawingID,
            image: image,
            originalSize: CGSize(width: 2, height: 3),
            doodleClassification: DoodleClassification(label: "bird", confidence: 0.9)
        )
        try makeV1Store(at: storeURL, drawing: drawing, cutout: cutout)

        // Act
        let container = try migratedContainer(at: storeURL)
        let records = try container.mainContext.fetch(FetchDescriptor<CreationRecord>())

        // Assert
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.id, drawingID)
        XCTAssertEqual(record.playableAssetID, assetID)
        XCTAssertEqual(record.sourceKindRawValue, CreationSourceKind.drawing.rawValue)
        XCTAssertEqual(record.predictedLabel, "bird")
        XCTAssertTrue(record.isTitleManuallyEdited)
    }

    func testMigrationPreservesPhotoOnlyCutoutAsLegacyCreation() throws {
        // Arrange
        let storeURL = temporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }
        let assetID = UUID()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image {
            UIColor.blue.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let cutout = CreationPlayableAsset(
            id: assetID,
            image: image,
            originalSize: CGSize(width: 2, height: 2)
        )
        try makeV1Store(at: storeURL, drawing: nil, cutout: cutout)

        // Act
        let container = try migratedContainer(at: storeURL)
        let records = try container.mainContext.fetch(FetchDescriptor<CreationRecord>())

        // Assert
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.id, assetID)
        XCTAssertEqual(
            record.sourceKindRawValue,
            CreationSourceKind.legacyProcessedImage.rawValue
        )
        XCTAssertEqual(record.playableAssetID, assetID)
        XCTAssertFalse(record.sourceData.isEmpty)
    }

    private func makeV1Store(
        at storeURL: URL,
        drawing: CreationDrawing?,
        cutout: CreationPlayableAsset
    ) throws {
        let schema = Schema(ArtworkSchemaV1.models)
        let configuration = ModelConfiguration(
            "ArtworkMigrationV1",
            schema: schema,
            url: storeURL
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        if let drawing {
            container.mainContext.insert(SavedDrawingRecord(drawing))
        }
        container.mainContext.insert(try XCTUnwrap(CutoutAssetRecord(cutout)))
        try container.mainContext.save()
    }

    private func migratedContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(ArtworkSchemaV2.models)
        let configuration = ModelConfiguration(
            "ArtworkMigrationV2",
            schema: schema,
            url: storeURL
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: ArtworkMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AniMagicMigration-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func removeStoreFiles(at storeURL: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(
                atPath: storeURL.path + suffix
            )
        }
    }
}
