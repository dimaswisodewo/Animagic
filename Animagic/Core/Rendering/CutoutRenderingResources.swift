//
//  CutoutRenderingResources.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Metal
import RealityKit
import UIKit

enum DenseCutoutMesh {
    static let subdivisions = 32

    static func generate(width: Float, height: Float) throws -> MeshResource {
        let columns = subdivisions + 1
        let rows = subdivisions + 1
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var textureCoordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        positions.reserveCapacity(columns * rows)
        normals.reserveCapacity(columns * rows)
        textureCoordinates.reserveCapacity(columns * rows)
        indices.reserveCapacity(subdivisions * subdivisions * 6)

        for row in 0..<rows {
            let v = Float(row) / Float(subdivisions)
            for column in 0..<columns {
                let u = Float(column) / Float(subdivisions)
                positions.append([(u - 0.5) * width, (0.5 - v) * height, 0])
                normals.append([0, 0, 1])
                textureCoordinates.append([u, v])
            }
        }

        for row in 0..<subdivisions {
            for column in 0..<subdivisions {
                let topLeft = UInt32((row * columns) + column)
                let topRight = topLeft + 1
                let bottomLeft = topLeft + UInt32(columns)
                let bottomRight = bottomLeft + 1
                indices.append(contentsOf: [
                    topLeft, bottomLeft, topRight,
                    topRight, bottomLeft, bottomRight
                ])
            }
        }

        var descriptor = MeshDescriptor(name: "Dense cutout plane")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

enum CutoutDeformationMaterial {
    static func make(
        texture: TextureResource,
        archetype: AnimalArchetype,
        phase: Float,
        faceDirection: Float
    ) throws -> CustomMaterial {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else {
            throw CutoutDeformationError.metalLibraryUnavailable
        }

        let surfaceShader = CustomMaterial.SurfaceShader(named: "cutoutSurface", in: library)
        let geometryModifier = CustomMaterial.GeometryModifier(named: "cutoutGeometryModifier", in: library)
        var material = try CustomMaterial(
            surfaceShader: surfaceShader,
            geometryModifier: geometryModifier,
            lightingModel: .unlit
        )
        material.custom.texture = .init(texture)
        material.custom.value = [archetype.shaderIndex, 1, phase, faceDirection]
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        return material
    }

    static func make(
        from image: CGImage,
        archetype: AnimalArchetype,
        phase: Float,
        faceDirection: Float
    ) throws -> CustomMaterial {
        let texture = try TextureResource(image: image, options: .init(semantic: .color))
        return try make(texture: texture, archetype: archetype, phase: phase, faceDirection: faceDirection)
    }

}

private enum CutoutDeformationError: Error {
    case metalLibraryUnavailable
}
