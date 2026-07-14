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
    let defaultPhysicalWidth: Float = 0.35

    var pngData: Data? {
        image.pngData()
    }
}

