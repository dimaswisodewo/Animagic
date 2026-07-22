//
//  ARSharedObjectPayload.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 22/07/26.
//

import RealityKit
import simd
import UIKit

struct ARSharedVector3: Codable, Equatable {
    let x: Float
    let y: Float
    let z: Float

    init(_ vector: SIMD3<Float>) {
        x = vector.x
        y = vector.y
        z = vector.z
    }

    var simdValue: SIMD3<Float> {
        [x, y, z]
    }
}

struct ARSharedTransform: Codable, Equatable {
    let position: ARSharedVector3
    let scale: ARSharedVector3
    let rotation: [Float]

    init(_ transform: Transform) {
        position = ARSharedVector3(transform.translation)
        scale = ARSharedVector3(transform.scale)
        rotation = [
            transform.rotation.vector.x,
            transform.rotation.vector.y,
            transform.rotation.vector.z,
            transform.rotation.vector.w
        ]
    }

    var realityKitTransform: Transform {
        let quaternion = simd_quatf(
            ix: rotation[safe: 0] ?? 0,
            iy: rotation[safe: 1] ?? 0,
            iz: rotation[safe: 2] ?? 0,
            r: rotation[safe: 3] ?? 1
        )
        return Transform(
            scale: scale.simdValue,
            rotation: quaternion,
            translation: position.simdValue
        )
    }
}

struct ARSharedMatrix4x4: Codable, Equatable {
    let values: [Float]

    init(_ matrix: simd_float4x4) {
        values = [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    var simdValue: simd_float4x4 {
        simd_float4x4(
            SIMD4(values[safe: 0] ?? 1, values[safe: 1] ?? 0, values[safe: 2] ?? 0, values[safe: 3] ?? 0),
            SIMD4(values[safe: 4] ?? 0, values[safe: 5] ?? 1, values[safe: 6] ?? 0, values[safe: 7] ?? 0),
            SIMD4(values[safe: 8] ?? 0, values[safe: 9] ?? 0, values[safe: 10] ?? 1, values[safe: 11] ?? 0),
            SIMD4(values[safe: 12] ?? 0, values[safe: 13] ?? 0, values[safe: 14] ?? 0, values[safe: 15] ?? 1)
        )
    }
}

struct ARSharedObjectContent: Codable, Equatable {
    enum Kind: String, Codable {
        case doodle
        case model
    }

    let kind: Kind
    let assetID: UUID?
    let imageData: Data?
    let originalSize: ARSharedVector3?
    let locomotion: String?
    let modelID: String?
    let doodleLabel: String?
    let doodleConfidence: Float?
    let doodleOverrideLabel: String?

    static func doodle(
        asset: CutoutAsset,
        locomotion: AnimalLocomotion
    ) -> Self? {
        guard let imageData = asset.pngData else { return nil }
        return Self(
            kind: .doodle,
            assetID: asset.id,
            imageData: imageData,
            originalSize: ARSharedVector3(SIMD3<Float>(
                Float(asset.originalSize.width),
                Float(asset.originalSize.height),
                0
            )),
            locomotion: locomotion.rawValue,
            modelID: nil,
            doodleLabel: asset.doodleClassification?.label,
            doodleConfidence: asset.doodleClassification?.confidence,
            doodleOverrideLabel: asset.doodleOverrideLabel
        )
    }

    static func model(_ modelID: PlaceableUSDZModel.ID) -> Self {
        Self(
            kind: .model,
            assetID: nil,
            imageData: nil,
            originalSize: nil,
            locomotion: nil,
            modelID: modelID.rawValue,
            doodleLabel: nil,
            doodleConfidence: nil,
            doodleOverrideLabel: nil
        )
    }

    var placedContent: PlacedObjectContent? {
        switch kind {
        case .doodle:
            guard let locomotion,
                  let animalLocomotion = AnimalLocomotion(rawValue: locomotion) else {
                return nil
            }
            return .doodle(animalLocomotion)
        case .model:
            guard let modelID,
                  let rawModelID = PlaceableUSDZModel.ID(rawValue: modelID) else {
                return nil
            }
            return .model(rawModelID)
        }
    }

    func cutoutAsset() -> CutoutAsset? {
        guard kind == .doodle,
              let assetID,
              let imageData,
              let image = UIImage(data: imageData) else {
            return nil
        }
        let size = originalSize.map { CGSize(width: CGFloat($0.x), height: CGFloat($0.y)) } ?? image.size
        let classification = doodleLabel.map {
            DoodleClassification(label: $0, confidence: doodleConfidence ?? 0)
        }
        return CutoutAsset(
            id: assetID,
            image: image,
            originalSize: size,
            doodleClassification: classification,
            doodleOverrideLabel: doodleOverrideLabel
        )
    }
}

struct ARSharedObjectPayload: Codable, Equatable {
    let id: UUID
    let content: ARSharedObjectContent
    let anchorTransform: ARSharedMatrix4x4
    let interactionTransform: ARSharedTransform
    let supportSurfaceNormal: ARSharedVector3
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
