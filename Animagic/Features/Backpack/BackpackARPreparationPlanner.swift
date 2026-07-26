//
//  BackpackARPreparationPlanner.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import Foundation

struct BackpackARPreparationPlanner {
    func missingDrawings(
        drawings: [SavedDrawing],
        cutouts: [CutoutAsset]
    ) -> [SavedDrawing] {
        let drawingIDsWithCutouts = Set(cutouts.compactMap(\.sourceDrawingID))
        return drawings.filter { drawing in
            !drawing.drawing.strokes.isEmpty
                && !drawing.drawing.bounds.isEmpty
                && !drawingIDsWithCutouts.contains(drawing.id)
        }
    }
}
