//
//  Creation.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation

public struct CreationID: Hashable, Identifiable, Sendable {
    public let rawValue: UUID

    public var id: UUID { rawValue }

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public enum CreationSourceKind: String, Codable, Sendable {
    case drawing
    case photo
    case legacyProcessedImage
}

public struct CreationSource: Equatable, Sendable {
    public let kind: CreationSourceKind
    public let data: Data
    public let mediaType: String?

    public init(kind: CreationSourceKind, data: Data, mediaType: String? = nil) {
        self.kind = kind
        self.data = data
        self.mediaType = mediaType
    }
}

public struct SpeciesPrediction: Equatable, Sendable {
    public let label: String
    public let confidence: Double

    public init(label: String, confidence: Double) {
        self.label = label
        self.confidence = confidence
    }
}

public struct SpeciesAssessment: Equatable, Sendable {
    public let prediction: SpeciesPrediction?
    public let overrideLabel: String?
    public let failureMessage: String?

    public var effectiveLabel: String? {
        overrideLabel ?? prediction?.label
    }

    public init(
        prediction: SpeciesPrediction? = nil,
        overrideLabel: String? = nil,
        failureMessage: String? = nil
    ) {
        self.prediction = prediction
        self.overrideLabel = overrideLabel
        self.failureMessage = failureMessage
    }
}

public enum Habitat: String, CaseIterable, Codable, Sendable {
    case land
    case skies
    case underwater

    public static func derived(fromSpeciesLabel label: String?) -> Self {
        guard let normalized = label?.lowercased() else { return .land }
        if skySpecies.contains(normalized) { return .skies }
        if underwaterSpecies.contains(normalized) { return .underwater }
        return .land
    }

    private static let skySpecies: Set<String> = [
        "bat", "bird", "duck", "flamingo", "owl", "parrot", "penguin", "swan",
        "bee", "butterfly", "mosquito"
    ]

    private static let underwaterSpecies: Set<String> = [
        "dolphin", "fish", "shark", "whale", "sea turtle", "octopus", "snail",
        "crab", "lobster"
    ]
}

public struct PlayableAsset: Equatable, Sendable {
    public let id: UUID
    public let imageData: Data
    public let pixelWidth: Double
    public let pixelHeight: Double

    public init(
        id: UUID = UUID(),
        imageData: Data,
        pixelWidth: Double,
        pixelHeight: Double
    ) {
        self.id = id
        self.imageData = imageData
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct Creation: Identifiable, Equatable, Sendable {
    public let id: CreationID
    public var title: String
    public var source: CreationSource
    public var playableAsset: PlayableAsset?
    public var speciesAssessment: SpeciesAssessment
    public var isTitleManuallyEdited: Bool
    public let createdAt: Date

    public var habitat: Habitat {
        .derived(fromSpeciesLabel: speciesAssessment.effectiveLabel)
    }

    public var isPlayable: Bool {
        playableAsset != nil
    }

    public init(
        id: CreationID = CreationID(),
        title: String,
        source: CreationSource,
        playableAsset: PlayableAsset? = nil,
        speciesAssessment: SpeciesAssessment = SpeciesAssessment(),
        isTitleManuallyEdited: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.playableAsset = playableAsset
        self.speciesAssessment = speciesAssessment
        self.isTitleManuallyEdited = isTitleManuallyEdited
        self.createdAt = createdAt
    }
}

public struct CreationSummary: Identifiable, Equatable, Sendable {
    public let id: CreationID
    public let title: String
    public let sourceKind: CreationSourceKind
    public let habitat: Habitat
    public let isPlayable: Bool
    public let createdAt: Date

    public init(_ creation: Creation) {
        id = creation.id
        title = creation.title
        sourceKind = creation.source.kind
        habitat = creation.habitat
        isPlayable = creation.isPlayable
        createdAt = creation.createdAt
    }
}

public struct PlayableCreation: Identifiable, Equatable, Sendable {
    public let id: CreationID
    public let title: String
    public let asset: PlayableAsset
    public let effectiveSpeciesLabel: String?
    public let habitat: Habitat

    public init?(_ creation: Creation) {
        guard let asset = creation.playableAsset else { return nil }
        id = creation.id
        title = creation.title
        self.asset = asset
        effectiveSpeciesLabel = creation.speciesAssessment.effectiveLabel
        habitat = creation.habitat
    }
}
