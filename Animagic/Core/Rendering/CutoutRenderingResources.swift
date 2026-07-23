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
        textureBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
        deformationMargin: Float = 0.06
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
            let normalizedV = Float(row) / Float(subdivisions)
            let v = mix(-deformationMargin, 1 + deformationMargin, normalizedV)
            for column in 0..<columns {
                let normalizedU = Float(column) / Float(subdivisions)
                let u = mix(-deformationMargin, 1 + deformationMargin, normalizedU)
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

    private static func mix(_ lower: Float, _ upper: Float, _ amount: Float) -> Float {
        lower + (upper - lower) * amount
    }
}

enum CutoutRenderQuality: Int, CaseIterable {
    case economy = 12
    case balanced = 20
    case hero = 32
}

struct CutoutDeformationState {
    let phase: Float
    let behavior: AnimalBehavior
    let behaviorProgress: Float
    // Reserved personality/compatibility input; shader-local behavior envelopes own amplitude.
    let activity: Float
    let normalizedSpeed: Float
    let steering: Float
    let contact: Float
    let contactProgress: Float
    let reactionProgress: Float
    let reactionStrength: Float
    let irregularity: Float
    let facing: Float

    init(sample: MotionSample, facing: Float) {
        phase = sample.deformationPhase
        behavior = sample.behavior
        behaviorProgress = sample.behaviorProgress
        activity = sample.deformationActivity
        normalizedSpeed = sample.normalizedSpeed
        steering = sample.steering
        contact = sample.contact
        contactProgress = sample.contactProgress
        reactionProgress = sample.reactionProgress
        reactionStrength = sample.reactionStrength
        irregularity = sample.deformationIrregularity
        self.facing = facing
    }

    static func initial(phase: Float, facing: Float) -> Self {
        Self(
            phase: phase,
            behavior: .moving,
            behaviorProgress: 0,
            activity: 1,
            normalizedSpeed: 0,
            steering: 0,
            contact: 0,
            contactProgress: 1,
            reactionProgress: 0,
            reactionStrength: 0,
            irregularity: 0,
            facing: facing
        )
    }

    private init(
        phase: Float,
        behavior: AnimalBehavior,
        behaviorProgress: Float,
        activity: Float,
        normalizedSpeed: Float,
        steering: Float,
        contact: Float,
        contactProgress: Float,
        reactionProgress: Float,
        reactionStrength: Float,
        irregularity: Float,
        facing: Float
    ) {
        self.phase = phase
        self.behavior = behavior
        self.behaviorProgress = behaviorProgress
        self.activity = activity
        self.normalizedSpeed = normalizedSpeed
        self.steering = steering
        self.contact = contact
        self.contactProgress = contactProgress
        self.reactionProgress = reactionProgress
        self.reactionStrength = reactionStrength
        self.irregularity = irregularity
        self.facing = facing
    }
}

enum CutoutSurfaceRole: Hashable {
    case front
    case back
    case rim

    var compensation: Float {
        switch self {
        case .front, .rim: 1
        case .back: -1
        }
    }
}

private struct GeometryUniformValues {
    var motion: SIMD4<Float>
    var state: SIMD4<Float>
    var reaction: SIMD4<Float>
    var geometry: SIMD4<Float>
    var texture: SIMD4<Float>

    init(
        state deformationState: CutoutDeformationState,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        surfaceRole: CutoutSurfaceRole
    ) {
        motion = [
            deformationState.phase,
            deformationState.activity,
            deformationState.normalizedSpeed,
            deformationState.steering
        ]
        state = [
            Float(deformationState.behavior.rawValue),
            deformationState.behaviorProgress,
            deformationState.contact,
            deformationState.contactProgress
        ]
        reaction = [
            deformationState.reactionProgress,
            deformationState.reactionStrength,
            deformationState.irregularity,
            deformationState.facing
        ]
        geometry = [
            physicalSize.x,
            physicalSize.y,
            Float(textureBounds.minX),
            Float(textureBounds.minY)
        ]
        texture = [
            Float(textureBounds.width),
            Float(textureBounds.height),
            surfaceRole.compensation,
            0
        ]
    }
}

private protocol GeometryUniformPack {
    init(values: GeometryUniformValues)
}

private protocol LocomotionShaderAdapter {
    var geometryModifierName: String { get }

    func initialize(
        material: inout CustomMaterial,
        state: CutoutDeformationState,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        surfaceRole: CutoutSurfaceRole
    )

    func update(
        material: inout CustomMaterial,
        state: CutoutDeformationState,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        surfaceRole: CutoutSurfaceRole
    )
}

private struct TypedLocomotionShaderAdapter<Uniforms: GeometryUniformPack>: LocomotionShaderAdapter {
    let geometryModifierName: String

    func initialize(
        material: inout CustomMaterial,
        state: CutoutDeformationState,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        surfaceRole: CutoutSurfaceRole
    ) {
        write(
            material: &material,
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: surfaceRole
        )
    }

    func update(
        material: inout CustomMaterial,
        state: CutoutDeformationState,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        surfaceRole: CutoutSurfaceRole
    ) {
        write(
            material: &material,
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: surfaceRole
        )
    }

    private func write(
        material: inout CustomMaterial,
        state: CutoutDeformationState,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        surfaceRole: CutoutSurfaceRole
    ) {
        let values = GeometryUniformValues(
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: surfaceRole
        )
        material.withMutableUniforms(ofType: Uniforms.self, stage: .geometryModifier) {
            uniforms, _ in
            uniforms = Uniforms(values: values)
        }
    }
}

// Each type intentionally mirrors its private Metal uniform definition.
private struct SwimGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct FlyGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct FlutterGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct WalkGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct StompGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct WaddleGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct HopGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct SlitherGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct CrawlGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct ScuttleGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private struct GenericGeometryUniforms: GeometryUniformPack {
    var motion, state, reaction, geometry, texture: SIMD4<Float>
    init(values: GeometryUniformValues) {
        (motion, state, reaction, geometry, texture) =
            (values.motion, values.state, values.reaction, values.geometry, values.texture)
    }
}

private extension AnimalLocomotion {
    var shaderAdapter: any LocomotionShaderAdapter {
        switch self {
        case .swim:
            TypedLocomotionShaderAdapter<SwimGeometryUniforms>(
                geometryModifierName: "swimGeometryModifier"
            )
        case .fly:
            TypedLocomotionShaderAdapter<FlyGeometryUniforms>(
                geometryModifierName: "flyGeometryModifier"
            )
        case .flutter:
            TypedLocomotionShaderAdapter<FlutterGeometryUniforms>(
                geometryModifierName: "flutterGeometryModifier"
            )
        case .walk:
            TypedLocomotionShaderAdapter<WalkGeometryUniforms>(
                geometryModifierName: "walkGeometryModifier"
            )
        case .stomp:
            TypedLocomotionShaderAdapter<StompGeometryUniforms>(
                geometryModifierName: "stompGeometryModifier"
            )
        case .waddle:
            TypedLocomotionShaderAdapter<WaddleGeometryUniforms>(
                geometryModifierName: "waddleGeometryModifier"
            )
        case .hop:
            TypedLocomotionShaderAdapter<HopGeometryUniforms>(
                geometryModifierName: "hopGeometryModifier"
            )
        case .slither:
            TypedLocomotionShaderAdapter<SlitherGeometryUniforms>(
                geometryModifierName: "slitherGeometryModifier"
            )
        case .crawl:
            TypedLocomotionShaderAdapter<CrawlGeometryUniforms>(
                geometryModifierName: "crawlGeometryModifier"
            )
        case .scuttle:
            TypedLocomotionShaderAdapter<ScuttleGeometryUniforms>(
                geometryModifierName: "scuttleGeometryModifier"
            )
        case .generic:
            TypedLocomotionShaderAdapter<GenericGeometryUniforms>(
                geometryModifierName: "genericGeometryModifier"
            )
        }
    }
}

final class CutoutShaderLibrary {
    private struct TemplateKey: Hashable {
        let locomotion: AnimalLocomotion
        let surfaceRole: CutoutSurfaceRole
    }

    private var templates: [TemplateKey: CustomMaterial] = [:]

    func prepareAllTemplates() throws {
        guard templates.count < AnimalLocomotion.allCases.count * 3 else { return }
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else {
            throw CutoutDeformationError.metalLibraryUnavailable
        }

        let surfaceShader = CustomMaterial.SurfaceShader(named: "cutoutSurface", in: library)
        for locomotion in AnimalLocomotion.allCases {
            for surfaceRole in [CutoutSurfaceRole.front, .back, .rim] {
                let key = TemplateKey(locomotion: locomotion, surfaceRole: surfaceRole)
                guard templates[key] == nil else { continue }
                let geometryModifier = CustomMaterial.GeometryModifier(
                    named: locomotion.shaderAdapter.geometryModifierName,
                    in: library
                )
                var material = try CustomMaterial(
                    surfaceShader: surfaceShader,
                    geometryModifier: geometryModifier,
                    lightingModel: .lit
                )
                material.blending = .transparent(opacity: .init(floatLiteral: 1))
                templates[key] = material
            }
        }
    }

    fileprivate func template(
        for locomotion: AnimalLocomotion,
        surfaceRole: CutoutSurfaceRole
    ) -> CustomMaterial {
        guard let template = templates[
            TemplateKey(locomotion: locomotion, surfaceRole: surfaceRole)
        ] else {
            preconditionFailure("CutoutShaderLibrary must be prepared before entity construction.")
        }
        return template
    }
}

struct CutoutDeformationMaterialPair {
    var front: CustomMaterial
    var back: CustomMaterial
}

final class CutoutDeformationMaterialController {
    private let shaderLibrary: CutoutShaderLibrary
    private let frontTexture: TextureResource
    private let backTexture: TextureResource
    private let physicalSize: SIMD2<Float>
    private let textureBounds: CGRect
    private var locomotion: AnimalLocomotion
    private var state: CutoutDeformationState
    private(set) var activeMaterials: CutoutDeformationMaterialPair

    init(
        shaderLibrary: CutoutShaderLibrary,
        frontTexture: TextureResource,
        backTexture: TextureResource,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        locomotion: AnimalLocomotion,
        phase: Float,
        facing: Float
    ) {
        self.shaderLibrary = shaderLibrary
        self.frontTexture = frontTexture
        self.backTexture = backTexture
        self.physicalSize = physicalSize
        self.textureBounds = textureBounds
        self.locomotion = locomotion
        state = .initial(phase: phase, facing: facing)
        activeMaterials = Self.makePair(
            shaderLibrary: shaderLibrary,
            frontTexture: frontTexture,
            backTexture: backTexture,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            locomotion: locomotion,
            state: state
        )
    }

    func setLocomotion(_ locomotion: AnimalLocomotion) -> CutoutDeformationMaterialPair {
        guard locomotion != self.locomotion else { return activeMaterials }
        self.locomotion = locomotion
        activeMaterials = Self.makePair(
            shaderLibrary: shaderLibrary,
            frontTexture: frontTexture,
            backTexture: backTexture,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            locomotion: locomotion,
            state: state
        )
        return activeMaterials
    }

    func update(with state: CutoutDeformationState) -> CutoutDeformationMaterialPair {
        self.state = state
        let adapter = locomotion.shaderAdapter
        adapter.update(
            material: &activeMaterials.front,
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: .front
        )
        adapter.update(
            material: &activeMaterials.back,
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: .back
        )
        return activeMaterials
    }

    private static func makePair(
        shaderLibrary: CutoutShaderLibrary,
        frontTexture: TextureResource,
        backTexture: TextureResource,
        physicalSize: SIMD2<Float>,
        textureBounds: CGRect,
        locomotion: AnimalLocomotion,
        state: CutoutDeformationState
    ) -> CutoutDeformationMaterialPair {
        let adapter = locomotion.shaderAdapter
        var front = shaderLibrary.template(for: locomotion, surfaceRole: .front)
        front.custom.texture = .init(frontTexture)
        adapter.initialize(
            material: &front,
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: .front
        )

        var back = shaderLibrary.template(for: locomotion, surfaceRole: .back)
        back.custom.texture = .init(backTexture)
        adapter.initialize(
            material: &back,
            state: state,
            physicalSize: physicalSize,
            textureBounds: textureBounds,
            surfaceRole: .back
        )
        return CutoutDeformationMaterialPair(front: front, back: back)
    }
}

private enum CutoutDeformationError: Error {
    case metalLibraryUnavailable
}
