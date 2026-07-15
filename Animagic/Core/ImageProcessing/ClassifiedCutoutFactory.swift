import UIKit

struct ClassifiedCutoutFactory {
    nonisolated init() {}

    nonisolated func makeCutout(
        from image: UIImage,
        originalSize: CGSize,
        sourceDrawingID: UUID
    ) -> CutoutAsset {
        let classificationResult = Result {
            try DoodleClassificationService().classify(image).get()
        }

        switch classificationResult {
        case .success(let classification):
            return CutoutAsset(
                sourceDrawingID: sourceDrawingID,
                image: image,
                originalSize: originalSize,
                doodleClassification: classification
            )
        case .failure(let error):
            return CutoutAsset(
                sourceDrawingID: sourceDrawingID,
                image: image,
                originalSize: originalSize,
                doodleClassificationError: error.localizedDescription
            )
        }
    }
}
