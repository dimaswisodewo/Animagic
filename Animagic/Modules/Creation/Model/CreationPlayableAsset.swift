//
//  CreationPlayableAsset.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Foundation
import UIKit

public struct CreationPlayableAsset: Identifiable {
    public let id: UUID
    public let sourceDrawingID: UUID?
    public let image: UIImage
    public let originalSize: CGSize
    public let doodleClassification: DoodleClassification?
    public let doodleClassificationError: String?
    public let doodleOverrideLabel: String?
    public let defaultPhysicalWidth: Float = 0.35

    public nonisolated init(
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

    public var pngData: Data? {
        image.pngData()
    }

    public var resolvedDoodleLabel: String? {
        doodleOverrideLabel ?? doodleClassification?.label
    }
}
