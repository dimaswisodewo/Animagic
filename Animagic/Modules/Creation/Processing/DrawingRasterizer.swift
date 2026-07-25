//
//  DrawingRasterizer.swift
//  AniMagic
//
//  Created by MorpKnight on 17/07/26.
//

import PencilKit
import UIKit

struct DrawingRaster {
    let image: UIImage
    let contentSize: CGSize
    let renderBounds: CGRect
}

enum DrawingRasterizerError: LocalizedError {
    case emptyDrawing
    case invalidBounds

    var errorDescription: String? {
        switch self {
        case .emptyDrawing:
            "The drawing is empty."
        case .invalidBounds:
            "The drawing bounds are invalid."
        }
    }
}

enum DrawingRasterizer {
    static func rasterize(
        _ drawing: PKDrawing,
        scale: CGFloat
    ) throws -> DrawingRaster {
        let bounds = drawing.bounds
        guard !drawing.strokes.isEmpty, !bounds.isEmpty else {
            throw DrawingRasterizerError.emptyDrawing
        }
        guard bounds.origin.x.isFinite,
              bounds.origin.y.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0 else {
            throw DrawingRasterizerError.invalidBounds
        }

        let padding = max(12, max(bounds.width, bounds.height) * 0.12)
        let renderBounds = bounds.insetBy(dx: -padding, dy: -padding)
        let image = drawing.image(from: renderBounds, scale: max(scale, 1))
            .normalizedForVision()

        return DrawingRaster(
            image: image,
            contentSize: bounds.size,
            renderBounds: renderBounds
        )
    }
}
