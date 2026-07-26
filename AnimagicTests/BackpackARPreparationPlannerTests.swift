//
//  BackpackARPreparationPlannerTests.swift
//  AniMagicTests
//
//  Created by dimaswisodewo on 26/07/26.
//

import PencilKit
import UIKit
import XCTest
@testable import AniMagic

final class BackpackARPreparationPlannerTests: XCTestCase {
    func testPlannerSkipsEmptyAndAlreadyPreparedDrawings() {
        // Arrange
        let emptyDrawing = SavedDrawing(name: "Empty", drawing: PKDrawing())
        let preparedDrawing = SavedDrawing(name: "Prepared", drawing: drawingWithStroke())
        let missingDrawing = SavedDrawing(name: "Missing", drawing: drawingWithStroke())
        let existingCutout = CutoutAsset(
            sourceDrawingID: preparedDrawing.id,
            image: UIImage(),
            originalSize: CGSize(width: 10, height: 10)
        )

        // Act
        let result = BackpackARPreparationPlanner().missingDrawings(
            drawings: [emptyDrawing, preparedDrawing, missingDrawing],
            cutouts: [existingCutout]
        )

        // Assert
        XCTAssertEqual(result.map(\.id), [missingDrawing.id])
    }

    private func drawingWithStroke() -> PKDrawing {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 0, y: 0),
                timeOffset: 0,
                size: CGSize(width: 5, height: 5),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: CGPoint(x: 20, y: 20),
                timeOffset: 0.1,
                size: CGSize(width: 5, height: 5),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        ]
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: path)])
    }
}
