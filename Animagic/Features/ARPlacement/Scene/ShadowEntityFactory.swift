//
//  ShadowEntityFactory.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import RealityKit
import UIKit

final class ShadowEntityFactory {
    private var cachedTexture: TextureResource?

    func makeEntity(width: Float, height: Float) throws -> ModelEntity {
        let texture = try shadowTexture()
        let shadowWidth = width * 0.72
        let shadowDepth = max(width * 0.22, height * 0.07)
        let mesh = MeshResource.generatePlane(width: shadowWidth, height: shadowDepth)
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(floatLiteral: 1))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [0, 0.002, 0]
        entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        entity.components.set(OpacityComponent(opacity: 1))
        return entity
    }

    private func shadowTexture() throws -> TextureResource {
        if let cachedTexture {
            return cachedTexture
        }
        guard let image = SoftShadowTexture.image.cgImage else {
            throw ShadowEntityFactoryError.imageGenerationFailed
        }
        let texture = try TextureResource(image: image, options: .init(semantic: .color))
        cachedTexture = texture
        return texture
    }
}

private enum ShadowEntityFactoryError: Error {
    case imageGenerationFailed
}
