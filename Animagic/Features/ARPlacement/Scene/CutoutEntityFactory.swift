//
//  CutoutEntityFactory.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import RealityKit
import UIKit

struct CutoutEntityParts {
    let root: Entity
    let body: Entity
    let shadow: ModelEntity?
    let front: ModelEntity
    let back: ModelEntity
    let physicalSize: SIMD2<Float>
    let bodyStyle: AnimalBodyStyle
    let meshes: [CutoutRenderQuality: MeshResource]
    let defaultFacing: Float
}

final class CutoutEntityFactory {
    private let shadowFactory: ShadowEntityFactory
    private var textureCache: [CutoutAsset.ID: TexturePair] = [:]
    private var meshCache: [MeshKey: MeshResource] = [:]

    private struct MeshKey: Hashable {
        let width: Int
        let height: Int
        let bounds: [Int]
        let subdivisions: Int
    }

    private struct TexturePair {
        let front: TextureResource
        let back: TextureResource
    }

    init(shadowFactory: ShadowEntityFactory = ShadowEntityFactory()) {
        self.shadowFactory = shadowFactory
    }

    func makeEntity(
        from asset: CutoutAsset,
        locomotion: AnimalLocomotion,
        objectID: UUID,
        physicalWidth: Float? = nil,
        showsShadow: Bool = true
    ) throws -> CutoutEntityParts {
        guard let cgImage = asset.image.cgImage else {
            throw CutoutEntityFactoryError.invalidImage
        }

        let rig = CutoutRigAnalyzer.analyze(cgImage)
        let visibleBounds = rig.visibleBounds
        let pixelWidth = CGFloat(cgImage.width) * visibleBounds.width
        let pixelHeight = CGFloat(cgImage.height) * visibleBounds.height
        let aspectRatio = Float(max(pixelWidth / max(pixelHeight, 1), 0.01))
        let width = physicalWidth ?? asset.defaultPhysicalWidth
        let height = width / aspectRatio
        let phase = Float.random(in: 0...(2 * Float.pi))
        let bodyStyle = AnimalMotionProfileResolver.profile(for: asset).bodyStyle
        let textures = try textures(for: asset, cgImage: cgImage)
        let frontMaterial = try CutoutDeformationMaterial.make(
            texture: textures.front,
            bodyStyle: bodyStyle,
            locomotion: locomotion,
            phase: phase,
            faceDirection: 1
        )
        let backMaterial = try CutoutDeformationMaterial.make(
            texture: textures.back,
            bodyStyle: bodyStyle,
            locomotion: locomotion,
            phase: phase,
            faceDirection: -1
        )

        let meshes = try Dictionary(uniqueKeysWithValues: CutoutRenderQuality.allCases.map { quality in
            let key = MeshKey(
                width: Int((width * 10_000).rounded()),
                height: Int((height * 10_000).rounded()),
                bounds: [visibleBounds.minX, visibleBounds.minY, visibleBounds.width, visibleBounds.height]
                    .map { Int(($0 * 1_000).rounded()) },
                subdivisions: quality.rawValue
            )
            if let cached = meshCache[key] { return (quality, cached) }
            let mesh = try DenseCutoutMesh.generate(
                width: width,
                height: height,
                subdivisions: quality.rawValue,
                textureBounds: visibleBounds
            )
            meshCache[key] = mesh
            return (quality, mesh)
        })
        guard let mesh = meshes[.balanced] else { throw CutoutEntityFactoryError.invalidImage }
        let frontEntity = ModelEntity(mesh: mesh, materials: [frontMaterial])
        frontEntity.position = [0, height / 2, 0.0005]
        let shadowComp = GroundingShadowComponent(castsShadow: false)
        frontEntity.components.set(shadowComp)

        let backEntity = ModelEntity(mesh: mesh, materials: [backMaterial])
        backEntity.position = [0, height / 2, -0.0005]
        backEntity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        backEntity.components.set(shadowComp)

        let bodyEntity = Entity()
        bodyEntity.addChild(frontEntity)
        bodyEntity.addChild(backEntity)
        bodyEntity.components.set(
            CollisionComponent(
                shapes: [
                    .generateBox(
                        width: width,
                        height: height,
                        depth: max(width * 0.04, 0.01)
                    ).offsetBy(translation: [0, height / 2, 0])
                ],
                mode: .default,
                filter: CollisionFilter(
                    group: .interactable,
                    mask: .interactable
                )
            )
        )
        bodyEntity.components.set(InputTargetComponent())
        bodyEntity.components.set(InteractableComponent(objectID: objectID))

        let rootEntity = Entity()
        rootEntity.addChild(bodyEntity)
        let shadowEntity = showsShadow
            ? try? shadowFactory.makeEntity(width: width, height: height)
            : nil
        if let shadowEntity {
            rootEntity.addChild(shadowEntity)
        }

        return CutoutEntityParts(
            root: rootEntity,
            body: bodyEntity,
            shadow: shadowEntity,
            front: frontEntity,
            back: backEntity,
            physicalSize: [width, height],
            bodyStyle: bodyStyle,
            meshes: meshes,
            defaultFacing: rig.defaultFacing
        )
    }

    private func textures(for asset: CutoutAsset, cgImage: CGImage) throws -> TexturePair {
        if let cached = textureCache[asset.id] {
            return cached
        }
        let front = try TextureResource(image: cgImage, options: .init(semantic: .color))
        let backImage = asset.image.mirroredHorizontally()?.cgImage ?? cgImage
        let back = try TextureResource(image: backImage, options: .init(semantic: .color))
        let pair = TexturePair(front: front, back: back)
        textureCache[asset.id] = pair
        return pair
    }
}

private enum CutoutEntityFactoryError: Error {
    case invalidImage
}
