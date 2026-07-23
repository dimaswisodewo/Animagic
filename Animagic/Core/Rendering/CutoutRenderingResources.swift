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
    static func generate(
        width: Float,
        height: Float,
        subdivisions: Int = 20,
        textureBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    ) throws -> MeshResource {
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
                textureCoordinates.append([
                    Float(textureBounds.minX) + u * Float(textureBounds.width),
                    Float(textureBounds.minY) + v * Float(textureBounds.height)
                ])
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

enum CutoutRenderQuality: Int, CaseIterable {
    case economy = 12
    case balanced = 20
    case hero = 32
}

struct SwimGeometryUniforms {
    // Keep these four-float groups in the same order as the Metal definition.
    // SIMD4 storage makes the cross-language argument-buffer alignment explicit.
    var motion: SIMD4<Float>
    var reaction: SIMD4<Float>
    var geometry: SIMD4<Float>
    var texture: SIMD4<Float>

    init(
        phase: Float,
        activity: Float,
        normalizedSpeed: Float,
        steering: Float,
        reactionProgress: Float,
        reactionStrength: Float,
        behavior: AnimalBehavior,
        faceDirection: Float,
        physicalWidth: Float,
        textureBounds: CGRect
    ) {
        motion = [phase, activity, normalizedSpeed, steering]
        reaction = [
            reactionProgress,
            reactionStrength,
            Float(behavior.rawValue),
            faceDirection
        ]
        geometry = [
            physicalWidth,
            Float(textureBounds.minX),
            Float(textureBounds.minY),
            Float(textureBounds.width)
        ]
        texture = [Float(textureBounds.height), 0, 0, 0]
    }
}

enum CutoutDeformationMaterial {
    static func makeTemplate(for locomotion: AnimalLocomotion) throws -> CustomMaterial {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else {
            throw CutoutDeformationError.metalLibraryUnavailable
        }

        let surfaceShader = CustomMaterial.SurfaceShader(named: "cutoutSurface", in: library)
        let geometryModifier = CustomMaterial.GeometryModifier(
            named: locomotion.geometryModifierName,
            in: library
        )
        var material = try CustomMaterial(
            surfaceShader: surfaceShader,
            geometryModifier: geometryModifier,
            lightingModel: .lit
        )
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        return material
    }

    static func make(
        from template: CustomMaterial,
        texture: TextureResource,
        bodyStyle: AnimalBodyStyle,
        locomotion: AnimalLocomotion,
        phase: Float,
        faceDirection: Float,
        physicalWidth: Float,
        textureBounds: CGRect
    ) -> CustomMaterial {
        var material = template
        material.custom.texture = .init(texture)
        if locomotion == .swim {
            material.withMutableUniforms(
                ofType: SwimGeometryUniforms.self,
                stage: .geometryModifier
            ) { uniforms, _ in
                uniforms = SwimGeometryUniforms(
                    phase: phase,
                    activity: 1,
                    normalizedSpeed: 0,
                    steering: 0,
                    reactionProgress: 0,
                    reactionStrength: 0,
                    behavior: .moving,
                    faceDirection: faceDirection,
                    physicalWidth: physicalWidth,
                    textureBounds: textureBounds
                )
            }
        } else {
            material.custom.value = [
                bodyStyle.shaderIndex + locomotion.shaderIndex * 0.01,
                1,
                phase,
                faceDirection
            ]
        }
        return material
    }

    static func updateSwim(
        material: inout CustomMaterial,
        sample: MotionSample,
        faceDirection: Float
    ) {
        material.withMutableUniforms(
            ofType: SwimGeometryUniforms.self,
            stage: .geometryModifier
        ) { uniforms, _ in
            let activity = sample.behavior == .coasting
                ? max(sample.deformationActivity, 0.55)
                : sample.deformationActivity
            uniforms.motion = [
                sample.deformationPhase,
                min(activity + sample.attention * 0.25, 1.25),
                sample.normalizedSpeed,
                sample.steering
            ]
            uniforms.reaction = [
                sample.reactionProgress,
                sample.reactionStrength,
                Float(sample.behavior.rawValue),
                faceDirection
            ]
        }
    }
}

private extension AnimalLocomotion {
    var geometryModifierName: String {
        self == .swim ? "swimGeometryModifier" : "cutoutGeometryModifier"
    }
}

private enum CutoutDeformationError: Error {
    case metalLibraryUnavailable
}
