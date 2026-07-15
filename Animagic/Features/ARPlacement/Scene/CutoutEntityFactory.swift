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
    let selectionIndicator: Entity
    let physicalSize: SIMD2<Float>
}

final class CutoutEntityFactory {
    private let shadowFactory: ShadowEntityFactory
    private var textureCache: [CutoutAsset.ID: TexturePair] = [:]
    private var meshCache: [MeshKey: MeshResource] = [:]

    private struct MeshKey: Hashable {
        let width: Int
        let height: Int
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
        archetype: AnimalArchetype,
        objectID: UUID,
        physicalWidth: Float? = nil
    ) throws -> CutoutEntityParts {
        guard let cgImage = asset.image.cgImage else {
            throw CutoutEntityFactoryError.invalidImage
        }

        let imageSize = asset.image.size
        let aspectRatio = Float(max(imageSize.width / max(imageSize.height, 1), 0.01))
        let width = physicalWidth ?? asset.defaultPhysicalWidth
        let height = width / aspectRatio
        let phase = Float.random(in: 0...(2 * Float.pi))
        let textures = try textures(for: asset, cgImage: cgImage)
        let frontMaterial = try CutoutDeformationMaterial.make(
            texture: textures.front,
            archetype: archetype,
            phase: phase,
            faceDirection: 1
        )
        let backMaterial = try CutoutDeformationMaterial.make(
            texture: textures.back,
            archetype: archetype,
            phase: phase,
            faceDirection: -1
        )

        let key = MeshKey(width: Int((width * 10_000).rounded()), height: Int((height * 10_000).rounded()))
        let mesh: MeshResource
        if let cached = meshCache[key] {
            mesh = cached
        } else {
            mesh = try DenseCutoutMesh.generate(width: width, height: height)
            meshCache[key] = mesh
        }
        let frontEntity = ModelEntity(mesh: mesh, materials: [frontMaterial])
        frontEntity.position = [0, height / 2, 0.0005]
        var shadowComp = GroundingShadowComponent(castsShadow: false)
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

        let selectionIndicator = makeSelectionIndicator(width: width, height: height)
        selectionIndicator.isEnabled = false
        bodyEntity.addChild(selectionIndicator)

        let rootEntity = Entity()
        rootEntity.addChild(bodyEntity)
        let shadowEntity = try? shadowFactory.makeEntity(width: width, height: height)
        if let shadowEntity {
            rootEntity.addChild(shadowEntity)
        }

        return CutoutEntityParts(
            root: rootEntity,
            body: bodyEntity,
            shadow: shadowEntity,
            front: frontEntity,
            back: backEntity,
            selectionIndicator: selectionIndicator,
            physicalSize: [width, height]
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

    private func makeSelectionIndicator(width: Float, height: Float) -> Entity {
        let container = Entity()
        let thickness = max(min(width, height) * 0.018, 0.003)
        var material = UnlitMaterial()
        material.color = .init(tint: .systemYellow)

        let horizontalMesh = MeshResource.generateBox(
            width: width + (thickness * 2),
            height: thickness,
            depth: thickness
        )
        let verticalMesh = MeshResource.generateBox(
            width: thickness,
            height: height + (thickness * 2),
            depth: thickness
        )

        let top = ModelEntity(mesh: horizontalMesh, materials: [material])
        top.position = [0, height + thickness / 2, 0.006]
        let bottom = ModelEntity(mesh: horizontalMesh, materials: [material])
        bottom.position = [0, -thickness / 2, 0.006]
        let left = ModelEntity(mesh: verticalMesh, materials: [material])
        left.position = [-(width / 2) - (thickness / 2), height / 2, 0.006]
        let right = ModelEntity(mesh: verticalMesh, materials: [material])
        right.position = [(width / 2) + (thickness / 2), height / 2, 0.006]

        container.addChild(top)
        container.addChild(bottom)
        container.addChild(left)
        container.addChild(right)
        return container
    }
}

private enum CutoutEntityFactoryError: Error {
    case invalidImage
}
