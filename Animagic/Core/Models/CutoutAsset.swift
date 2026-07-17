//
//  CutoutAsset.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Foundation
import UIKit

struct CutoutAsset: Identifiable {
    let id: UUID
    let sourceDrawingID: UUID?
    let image: UIImage
    let originalSize: CGSize
    let doodleClassification: DoodleClassification?
    let doodleClassificationError: String?
    let doodleOverrideLabel: String?
    let defaultPhysicalWidth: Float = 0.35

    nonisolated init(
        id: UUID = UUID(),
        sourceDrawingID: UUID? = nil,
        image: UIImage,
        originalSize: CGSize,
        doodleClassification: DoodleClassification? = nil,
        doodleClassificationError: String? = nil,
        doodleOverrideLabel: String? = nil
    ) {
        self.id = id
        self.sourceDrawingID = sourceDrawingID
        self.image = image
        self.originalSize = originalSize
        self.doodleClassification = doodleClassification
        self.doodleClassificationError = doodleClassificationError
        self.doodleOverrideLabel = doodleOverrideLabel
    }

    var pngData: Data? {
        image.pngData()
    }

    var resolvedDoodleLabel: String? {
        doodleOverrideLabel ?? doodleClassification?.label
    }
}
