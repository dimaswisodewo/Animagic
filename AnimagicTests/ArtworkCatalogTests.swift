//
//  ArtworkCatalogTests.swift
//  AniMagicTests
//
//  Created by dimaswisodewo on 26/07/26.
//

import PencilKit
import UIKit
import XCTest
@testable import AniMagic

final class ArtworkCatalogTests: XCTestCase {
    func testTemporaryPhotoCutoutIsProjectedFirst() {
        // Arrange
        let drawing = SavedDrawing(name: "Bear", drawing: PKDrawing())
        let savedCutout = makeCutout(sourceDrawingID: drawing.id)
        let photoCutout = makeCutout(
            classification: DoodleClassification(label: "fox", confidence: 0.9)
        )

        // Act
        let items = ArtworkLibraryPresentation.backpackCutoutItems(
            drawings: [drawing],
            cutouts: [savedCutout, photoCutout],
            temporaryCutoutID: photoCutout.id
        )

        // Assert
        XCTAssertEqual(items.map(\.id), [photoCutout.id, savedCutout.id])
        XCTAssertEqual(items.first?.title, "Fox")
    }

    private func makeCutout(
        sourceDrawingID: UUID? = nil,
        classification: DoodleClassification? = nil
    ) -> CutoutAsset {
        CutoutAsset(
            sourceDrawingID: sourceDrawingID,
            image: UIImage(),
            originalSize: CGSize(width: 10, height: 10),
            doodleClassification: classification
        )
    }
}
