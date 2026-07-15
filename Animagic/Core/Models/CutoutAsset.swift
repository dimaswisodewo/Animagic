//
//  CutoutAsset.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Foundation
import UIKit

struct CutoutAsset: Identifiable {
    let id = UUID()
    let image: UIImage
    let originalSize: CGSize
    let doodleClassification: DoodleClassification?
    let doodleClassificationError: String?
    let defaultPhysicalWidth: Float = 0.35

    init(
        image: UIImage,
        originalSize: CGSize,
        doodleClassification: DoodleClassification? = nil,
        doodleClassificationError: String? = nil
    ) {
        self.image = image
        self.originalSize = originalSize
        self.doodleClassification = doodleClassification
        self.doodleClassificationError = doodleClassificationError
    }

    var pngData: Data? {
        image.pngData()
    }
}
