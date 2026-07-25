//
//  CreationRecord.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation
import SwiftData

@Model
public final class CreationRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var sourceKindRawValue: String
    @Attribute(.externalStorage) public var sourceData: Data
    public var sourceMediaType: String?
    public var playableAssetID: UUID?
    @Attribute(.externalStorage) public var playableImageData: Data?
    public var playablePixelWidth: Double?
    public var playablePixelHeight: Double?
    public var predictedLabel: String?
    public var predictionConfidence: Double?
    public var classificationError: String?
    public var overrideLabel: String?
    public var isTitleManuallyEdited: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        title: String,
        sourceKind: CreationSourceKind,
        sourceData: Data,
        sourceMediaType: String? = nil,
        playableAssetID: UUID? = nil,
        playableImageData: Data? = nil,
        playablePixelWidth: Double? = nil,
        playablePixelHeight: Double? = nil,
        predictedLabel: String? = nil,
        predictionConfidence: Double? = nil,
        classificationError: String? = nil,
        overrideLabel: String? = nil,
        isTitleManuallyEdited: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        sourceKindRawValue = sourceKind.rawValue
        self.sourceData = sourceData
        self.sourceMediaType = sourceMediaType
        self.playableAssetID = playableAssetID
        self.playableImageData = playableImageData
        self.playablePixelWidth = playablePixelWidth
        self.playablePixelHeight = playablePixelHeight
        self.predictedLabel = predictedLabel
        self.predictionConfidence = predictionConfidence
        self.classificationError = classificationError
        self.overrideLabel = overrideLabel
        self.isTitleManuallyEdited = isTitleManuallyEdited
        self.createdAt = createdAt
    }

    public convenience init(_ creation: Creation) {
        self.init(
            id: creation.id.rawValue,
            title: creation.title,
            sourceKind: creation.source.kind,
            sourceData: creation.source.data,
            sourceMediaType: creation.source.mediaType,
            playableAssetID: creation.playableAsset?.id,
            playableImageData: creation.playableAsset?.imageData,
            playablePixelWidth: creation.playableAsset?.pixelWidth,
            playablePixelHeight: creation.playableAsset?.pixelHeight,
            predictedLabel: creation.speciesAssessment.prediction?.label,
            predictionConfidence: creation.speciesAssessment.prediction?.confidence,
            classificationError: creation.speciesAssessment.failureMessage,
            overrideLabel: creation.speciesAssessment.overrideLabel,
            isTitleManuallyEdited: creation.isTitleManuallyEdited,
            createdAt: creation.createdAt
        )
    }

    public func asValue() -> Creation {
        let sourceKind = CreationSourceKind(rawValue: sourceKindRawValue) ?? .legacyProcessedImage
        let asset: PlayableAsset? = playableAssetID.flatMap { assetID -> PlayableAsset? in
            guard let playableImageData,
                  let playablePixelWidth,
                  let playablePixelHeight else {
                return nil
            }
            return PlayableAsset(
                id: assetID,
                imageData: playableImageData,
                pixelWidth: playablePixelWidth,
                pixelHeight: playablePixelHeight
            )
        }
        let prediction = predictedLabel.map {
            SpeciesPrediction(label: $0, confidence: predictionConfidence ?? 0)
        }
        return Creation(
            id: CreationID(id),
            title: title,
            source: CreationSource(
                kind: sourceKind,
                data: sourceData,
                mediaType: sourceMediaType
            ),
            playableAsset: asset,
            speciesAssessment: SpeciesAssessment(
                prediction: prediction,
                overrideLabel: overrideLabel,
                failureMessage: classificationError
            ),
            isTitleManuallyEdited: isTitleManuallyEdited,
            createdAt: createdAt
        )
    }

    public func update(from creation: Creation) {
        title = creation.title
        sourceKindRawValue = creation.source.kind.rawValue
        sourceData = creation.source.data
        sourceMediaType = creation.source.mediaType
        playableAssetID = creation.playableAsset?.id
        playableImageData = creation.playableAsset?.imageData
        playablePixelWidth = creation.playableAsset?.pixelWidth
        playablePixelHeight = creation.playableAsset?.pixelHeight
        predictedLabel = creation.speciesAssessment.prediction?.label
        predictionConfidence = creation.speciesAssessment.prediction?.confidence
        classificationError = creation.speciesAssessment.failureMessage
        overrideLabel = creation.speciesAssessment.overrideLabel
        isTitleManuallyEdited = creation.isTitleManuallyEdited
    }
}
