//
//  CutoutEntityFactory.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import os
import RealityKit
import UIKit

struct CutoutEntityParts {
    let root: Entity
    let body: Entity
    let shadow: ModelEntity?
    let front: ModelEntity
    let back: ModelEntity
    let physicalSize: SIMD2<Float>
    let meshes: [CutoutRenderQuality: MeshResource]
    let deformationController: CutoutDeformationMaterialController
    let defaultFacing: Float
}

final class CutoutEntityFactory {
    private static let signposter = OSSignposter(
        subsystem: "com.DirouDough.AniMagic",
        category: "AR Doodle Placement"
    )

    private let shadowFactory: ShadowEntityFactory
    private var rigCache: [CutoutAsset.ID: CutoutRigDescriptor] = [:]
    private var textureCache: [CutoutAsset.ID: TexturePair] = [:]
    private var meshCache: [MeshKey: MeshResource] = [:]
    private let shaderLibrary = CutoutShaderLibrary()

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

    init(shadowFactory: ShadowEntityFactory? = nil) {
        self.shadowFactory = shadowFactory ?? ShadowEntityFactory()
    }

    func prepareResources(
        for asset: CutoutAsset,
        physicalWidth: Float? = nil
    ) throws {
        let signpostState = Self.signposter.beginInterval("Prepare Doodle Resources")
        defer { Self.signposter.endInterval("Prepare Doodle Resources", signpostState) }

        guard let cgImage = asset.image.cgImage else {
            throw CutoutEntityFactoryError.invalidImage
        }
        let rig = rig(for: asset, cgImage: cgImage)
        let size = physicalSize(for: asset, cgImage: cgImage, rig: rig, physicalWidth: physicalWidth)
        _ = try textures(for: asset, cgImage: cgImage)
        _ = try meshes(width: size.x, height: size.y, visibleBounds: rig.visibleBounds)
        try shaderLibrary.prepareAllTemplates()
    }

    func makeEntity(
        from asset: CutoutAsset,
        locomotion: AnimalLocomotion,
        objectID: UUID,
        physicalWidth: Float? = nil,
        showsShadow: Bool = true
    ) throws -> CutoutEntityParts {
        let signpostState = Self.signposter.beginInterval("Assemble Doodle Entity")
        defer { Self.signposter.endInterval("Assemble Doodle Entity", signpostState) }

        guard let cgImage = asset.image.cgImage else {
            throw CutoutEntityFactoryError.invalidImage
        }

        let rig = rig(for: asset, cgImage: cgImage)
        let visibleBounds = rig.visibleBounds
        let size = physicalSize(for: asset, cgImage: cgImage, rig: rig, physicalWidth: physicalWidth)
        let width = size.x
        let height = size.y
        let phase = Float.random(in: 0...(2 * Float.pi))
        let textures = try textures(for: asset, cgImage: cgImage)
        try shaderLibrary.prepareAllTemplates()
        let deformationController = CutoutDeformationMaterialController(
            shaderLibrary: shaderLibrary,
            frontTexture: textures.front,
            backTexture: textures.back,
            physicalSize: size,
            textureBounds: visibleBounds,
            locomotion: locomotion,
            phase: phase,
            facing: rig.defaultFacing
        )
        let activeMaterials = deformationController.activeMaterials

        let meshes = try meshes(width: width, height: height, visibleBounds: visibleBounds)
        guard let mesh = meshes[.balanced] else { throw CutoutEntityFactoryError.invalidImage }
        let frontEntity = ModelEntity(mesh: mesh, materials: [activeMaterials.front])
        frontEntity.position = [0, height / 2, 0.0005]
        let shadowComp = GroundingShadowComponent(castsShadow: false)
        frontEntity.components.set(shadowComp)

        let backEntity = ModelEntity(mesh: mesh, materials: [activeMaterials.back])
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
            meshes: meshes,
            deformationController: deformationController,
            defaultFacing: rig.defaultFacing
        )
    }

    private func rig(for asset: CutoutAsset, cgImage: CGImage) -> CutoutRigDescriptor {
        if let cached = rigCache[asset.id] {
            return cached
        }
        let rig = CutoutRigAnalyzer.analyze(cgImage)
        rigCache[asset.id] = rig
        return rig
    }

    private func physicalSize(
        for asset: CutoutAsset,
        cgImage: CGImage,
        rig: CutoutRigDescriptor,
        physicalWidth: Float?
    ) -> SIMD2<Float> {
        let pixelWidth = CGFloat(cgImage.width) * rig.visibleBounds.width
        let pixelHeight = CGFloat(cgImage.height) * rig.visibleBounds.height
        let aspectRatio = Float(max(pixelWidth / max(pixelHeight, 1), 0.01))
        let width = physicalWidth ?? asset.defaultPhysicalWidth
        return [width, width / aspectRatio]
    }

    private func meshes(
        width: Float,
        height: Float,
        visibleBounds: CGRect
    ) throws -> [CutoutRenderQuality: MeshResource] {
        try Dictionary(uniqueKeysWithValues: CutoutRenderQuality.allCases.map { quality in
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
