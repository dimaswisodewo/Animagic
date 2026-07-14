//
//  DoodleClassification.swift
//  Animagic
//

import CoreML
import Foundation
import Vision

struct DoodleClassification: Equatable {
    let label: String
    let confidence: Float
}

protocol DoodleClassifying {
    func classify(_ image: CGImage) throws -> DoodleClassification
}

struct AnimalSpeciesDoodleClassifier: DoodleClassifying {
    private let visionModel: VNCoreMLModel

    init(bundle: Bundle = .main) throws {
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

    func classify(_ image: CGImage) throws -> DoodleClassification {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        guard let result = request.results?.first as? VNClassificationObservation else {
            throw DoodleClassificationError.noClassification
        }
        return DoodleClassification(
            label: result.identifier,
            confidence: result.confidence
        )
    }
}

enum DoodleClassificationError: LocalizedError {
    case modelNotFound
    case noClassification

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "The animal doodle classifier could not be loaded."
        case .noClassification:
            return "The animal doodle classifier did not return a result."
        }
    }
}
