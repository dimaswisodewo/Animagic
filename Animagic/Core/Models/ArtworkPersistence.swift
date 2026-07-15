import Foundation
import PencilKit
import SwiftData
import UIKit

@Model
final class SavedDrawingRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRawValue: String
    @Attribute(.externalStorage) var drawingData: Data
    var predictedLabel: String?
    var predictionConfidence: Double?
    var overrideLabel: String?
    var isNameManuallyEdited: Bool = false
    var createdAt: Date

    init(_ drawing: SavedDrawing) {
        id = drawing.id
        name = drawing.name
        categoryRawValue = drawing.category.rawValue
        drawingData = drawing.drawing.dataRepresentation()
        predictedLabel = drawing.doodleClassification?.label
        predictionConfidence = drawing.doodleClassification.map { Double($0.confidence) }
        overrideLabel = drawing.doodleOverrideLabel
        isNameManuallyEdited = drawing.isNameManuallyEdited
        createdAt = drawing.createdAt
    }

    func asValue() -> SavedDrawing? {
        guard let drawing = try? PKDrawing(data: drawingData) else { return nil }
        return SavedDrawing(
            id: id,
            name: name,
            drawing: drawing,
            category: ArtworkCategory(rawValue: categoryRawValue) ?? .land,
            doodleClassification: predictedLabel.map {
                DoodleClassification(label: $0, confidence: Float(predictionConfidence ?? 0))
            },
            doodleOverrideLabel: overrideLabel,
            isNameManuallyEdited: isNameManuallyEdited,
            createdAt: createdAt
        )
    }
}

@Model
final class CutoutAssetRecord {
    @Attribute(.unique) var id: UUID
    var sourceDrawingID: UUID?
    @Attribute(.externalStorage) var imageData: Data
    var originalWidth: Double
    var originalHeight: Double
    var predictedLabel: String?
    var predictionConfidence: Double?
    var classificationError: String?
    var overrideLabel: String?

    init?(_ asset: CutoutAsset) {
        guard let imageData = asset.pngData else { return nil }
        id = asset.id
        sourceDrawingID = asset.sourceDrawingID
        self.imageData = imageData
        originalWidth = asset.originalSize.width
        originalHeight = asset.originalSize.height
        predictedLabel = asset.doodleClassification?.label
        predictionConfidence = asset.doodleClassification.map { Double($0.confidence) }
        classificationError = asset.doodleClassificationError
        overrideLabel = asset.doodleOverrideLabel
    }

    func asValue() -> CutoutAsset? {
        guard let image = UIImage(data: imageData) else { return nil }
        return CutoutAsset(
            id: id,
            sourceDrawingID: sourceDrawingID,
            image: image,
            originalSize: CGSize(width: originalWidth, height: originalHeight),
            doodleClassification: predictedLabel.map {
                DoodleClassification(label: $0, confidence: Float(predictionConfidence ?? 0))
            },
            doodleClassificationError: classificationError,
            doodleOverrideLabel: overrideLabel
        )
    }
}
