//
//  DoodleClassification.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import CoreGraphics

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
