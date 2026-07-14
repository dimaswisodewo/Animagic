//
//  VisionForegroundCutoutProcessor.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import CoreImage
import Foundation
import ImageIO
import UIKit
import Vision

struct VisionForegroundCutoutProcessor: CutoutProcessing {
    private let doodleClassifier: (any DoodleClassifying)?

    init(doodleClassifier: (any DoodleClassifying)? = try? AnimalSpeciesDoodleClassifier()) {
        self.doodleClassifier = doodleClassifier
    }

    func makeCutout(from imageData: Data) async throws -> CutoutAsset {
        guard let sourceImage = UIImage(data: imageData),
              let sourceCGImage = Self.downsampledCGImage(from: imageData, maxDimension: 2048) else {
            throw CutoutProcessingError.invalidImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: sourceCGImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw CutoutProcessingError.noForegroundObject
        }

        let outputBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )
        let output = CIImage(cvPixelBuffer: outputBuffer)
        guard let outputCGImage = Self.renderingContext.createCGImage(output, from: output.extent) else {
            throw CutoutProcessingError.renderFailed
        }

        let cutoutImage = UIImage(
            cgImage: outputCGImage,
            scale: 1,
            orientation: .up
        )
        let classification = try? doodleClassifier?.classify(sourceCGImage)
        return CutoutAsset(
            image: cutoutImage,
            originalSize: sourceImage.size,
            doodleClassification: classification
        )
    }

    private static func downsampledCGImage(from data: Data, maxDimension: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static let renderingContext = CIContext(options: nil)
}

enum CutoutProcessingError: LocalizedError {
    case invalidImage
    case noForegroundObject
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image could not be loaded."
        case .noForegroundObject:
            return "Vision could not find a foreground object in this image."
        case .renderFailed:
            return "The transparent object image could not be rendered."
        }
    }
}
