import UIKit

struct ClassifiedCutoutFactory {
    nonisolated init() {}

    nonisolated func makeCutout(
        from image: UIImage,
        originalSize: CGSize,
        sourceDrawingID: UUID
    ) -> CreationPlayableAsset {
        let classificationResult = Result {
            try DoodleClassificationService().classify(image).get()
        }

        switch classificationResult {
        case .success(let classification):
            return CreationPlayableAsset(
                sourceDrawingID: sourceDrawingID,
                image: image,
                originalSize: originalSize,
                doodleClassification: classification
            )
        case .failure(let error):
            return CreationPlayableAsset(
                sourceDrawingID: sourceDrawingID,
                image: image,
                originalSize: originalSize,
                doodleClassificationError: error.localizedDescription
            )
        }
    }
}
