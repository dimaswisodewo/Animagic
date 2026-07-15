//
//  DoodleClassification.swift
//  Animagic
//

import CoreML
import Foundation
import UIKit
import Vision

struct DoodleClassification: Equatable {
    let label: String
    let confidence: Float

    nonisolated init(label: String, confidence: Float) {
        self.label = label
        self.confidence = confidence
    }
}

protocol DoodleClassifying {
    nonisolated func classify(_ image: CGImage) throws -> DoodleClassification
}

struct AnimalSpeciesDoodleClassifier: DoodleClassifying {
    nonisolated(unsafe) private let visionModel: VNCoreMLModel

    nonisolated init(bundle: Bundle = .main) throws {
        guard let modelURL = bundle.url(
            forResource: "AnimalSpeciesClassifierV4",
            withExtension: "mlmodelc"
        ) else {
            throw DoodleClassificationError.modelNotFound
        }

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    nonisolated func classify(_ image: CGImage) throws -> DoodleClassification {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(cgImage: try Self.preprocess(image))
        try handler.perform([request])

        guard let result = (request.results as? [VNClassificationObservation])?.max(by: {
            $0.confidence < $1.confidence
        }) else {
            throw DoodleClassificationError.noClassification
        }
        return DoodleClassification(
            label: result.identifier,
            confidence: result.confidence
        )
    }

    nonisolated private static func preprocess(_ image: CGImage) throws -> CGImage {
        let canvasSize = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let normalizedImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            let sourceSize = CGSize(width: image.width, height: image.height)
            let scale = min(canvasSize.width / sourceSize.width, canvasSize.height / sourceSize.height)
            let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let origin = CGPoint(
                x: (canvasSize.width - scaledSize.width) / 2,
                y: (canvasSize.height - scaledSize.height) / 2
            )
            UIImage(cgImage: image).draw(in: CGRect(origin: origin, size: scaledSize))
        }

        guard let input = CIImage(image: normalizedImage),
              let grayscale = CIFilter(name: "CIColorControls", parameters: [
                  kCIInputImageKey: input,
                  kCIInputSaturationKey: 0
              ])?.outputImage,
              let inverted = CIFilter(name: "CIColorInvert", parameters: [
                  kCIInputImageKey: grayscale
              ])?.outputImage,
              let output = CIContext().createCGImage(inverted, from: inverted.extent) else {
            throw DoodleClassificationError.preprocessingFailed
        }
        return output
    }
}

enum DoodleClassificationError: LocalizedError {
    case modelNotFound
    case noClassification
    case invalidImage
    case preprocessingFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "The animal doodle classifier could not be loaded."
        case .noClassification:
            return "The animal doodle classifier did not return a result."
        case .invalidImage:
            return "The doodle image could not be prepared for classification."
        case .preprocessingFailed:
            return "The doodle image could not be normalized for the classifier."
        }
    }
}

struct DoodleClassificationService {
    nonisolated(unsafe) private let classifier: any DoodleClassifying

    nonisolated init(classifier: (any DoodleClassifying)? = nil) throws {
        self.classifier = try classifier ?? AnimalSpeciesDoodleClassifier()
    }

    nonisolated func classify(_ image: UIImage) -> Result<DoodleClassification, Error> {
        guard let cgImage = image.cgImage else {
            return .failure(DoodleClassificationError.invalidImage)
        }
        return Result { try classifier.classify(cgImage) }
    }
}
