//
//  CardboardRimMeshGenerator.swift
//  AniMagic
//
//  Created by dimaswisodewo on 23/07/26.
//

import Foundation
import RealityKit
import simd

enum CardboardRimStyle: Equatable {
    case softened
    case straight
}

struct CardboardRimMeshes {
    let economy: MeshResource
    let balanced: MeshResource
    let hero: MeshResource
    let thickness: Float
    let crownHeight: Float
    let style: CardboardRimStyle
    let surfaceField: CardboardSurfaceField?

    subscript(quality: CutoutRenderQuality) -> MeshResource {
        switch quality {
        case .economy: economy
        case .balanced: balanced
        case .hero: hero
        }
    }
}

enum CardboardRimMeshGenerator {
    private static var cache: [CacheKey: CardboardRimMeshes] = [:]
    private static let cacheLock = NSLock()

    static func generate(
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>
    ) throws -> CardboardRimMeshes {
        guard physicalSize.x.isFinite, physicalSize.y.isFinite,
              physicalSize.x > 0, physicalSize.y > 0,
              !contours.outerLoops.isEmpty else {
            throw CardboardRimMeshGenerationError.invalidContours
        }
        let thickness = min(max(physicalSize.x * 0.015, 0.003), 0.008)
        let key = CacheKey(
            contourFingerprint: contours.fingerprint,
            width: Int((physicalSize.x * 10_000).rounded()),
            height: Int((physicalSize.y * 10_000).rounded()),
            thickness: Int((thickness * 100_000).rounded())
        )
        cacheLock.lock()
        let cached = cache[key]
        cacheLock.unlock()
        if let cached { return cached }

        let meshes: CardboardRimMeshes
        do {
            meshes = try generateSoftened(
                contours: contours,
                physicalSize: physicalSize,
                thickness: thickness
            )
        } catch {
            meshes = try generateStraight(
                contours: contours,
                physicalSize: physicalSize,
                thickness: thickness
            )
        }
        cacheLock.lock()
        cache[key] = meshes
        cacheLock.unlock()
        return meshes
    }

    private static func generateSoftened(
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>,
        thickness: Float
    ) throws -> CardboardRimMeshes {
        let preferredRadius = min(
            min(max(physicalSize.x * 0.006, 0.001), 0.002),
            thickness * 0.38
        )
        let economy = try buildSoftenedGeometry(
            contours: contours,
            physicalSize: physicalSize,
            limit: 64,
            thickness: thickness,
            preferredRadius: preferredRadius,
            bevelSegments: 2
        )
        let balanced = try buildSoftenedGeometry(
            contours: contours,
            physicalSize: physicalSize,
            limit: 128,
            thickness: thickness,
            preferredRadius: preferredRadius,
            bevelSegments: 3
        )
        let hero = try buildSoftenedGeometry(
            contours: contours,
            physicalSize: physicalSize,
            limit: 256,
            thickness: thickness,
            preferredRadius: preferredRadius,
            bevelSegments: 4
        )
        let field = try CardboardSurfaceField.generate(
            loops: hero.loops,
            contours: contours,
            physicalSize: physicalSize
        )
        let crownHeight = min(thickness * 0.18, 0.0012)
        return CardboardRimMeshes(
            economy: try generateMesh(from: economy.geometry, name: "Soft cardboard rim economy"),
            balanced: try generateMesh(from: balanced.geometry, name: "Soft cardboard rim balanced"),
            hero: try generateMesh(from: hero.geometry, name: "Soft cardboard rim hero"),
            thickness: thickness,
            crownHeight: crownHeight,
            style: .softened,
            surfaceField: field
        )
    }

    private static func generateStraight(
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>,
        thickness: Float
    ) throws -> CardboardRimMeshes {
        CardboardRimMeshes(
            economy: try generateMesh(
                from: buildGeometry(
                    contours: contours,
                    physicalSize: physicalSize,
                    limit: 64,
                    thickness: thickness
                ),
                name: "Straight cardboard rim economy"
            ),
            balanced: try generateMesh(
                from: buildGeometry(
                    contours: contours,
                    physicalSize: physicalSize,
                    limit: 128,
                    thickness: thickness
                ),
                name: "Straight cardboard rim balanced"
            ),
            hero: try generateMesh(
                from: buildGeometry(
                    contours: contours,
                    physicalSize: physicalSize,
                    limit: 256,
                    thickness: thickness
                ),
                name: "Straight cardboard rim hero"
            ),
            thickness: thickness,
            crownHeight: 0,
            style: .straight,
            surfaceField: nil
        )
    }

    private static func generateMesh(
        from geometry: CardboardRimGeometry,
        name: String
    ) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(geometry.positions)
        descriptor.normals = MeshBuffers.Normals(geometry.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(geometry.textureCoordinates)
        descriptor.primitives = .triangles(geometry.indices)
        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            throw CardboardRimMeshGenerationError.meshGenerationFailed(error)
        }
    }

    static func buildSoftenedGeometry(
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>,
        limit: Int,
        thickness: Float,
        preferredRadius: Float,
        bevelSegments: Int
    ) throws -> SoftenedCardboardGeometry {
        guard bevelSegments >= 1, preferredRadius > 0, preferredRadius < thickness / 2 else {
            throw CardboardRimMeshGenerationError.invalidBevel
        }
        var geometry = CardboardRimGeometry()
        var beveledLoops: [BeveledContourLoop] = []
        for sourceLoop in contours.outerLoops + contours.holeLoops {
            let textureLoop = resampled(sourceLoop, maximumCount: limit)
            let points = textureLoop.map {
                meshPoint($0, bounds: contours.textureBounds, size: physicalSize)
            }
            guard points.count >= 4 else {
                throw CardboardRimMeshGenerationError.insufficientVertices
            }
            let outwardNormals = try vertexNormals(for: points)
            var radii = locallySafeRadii(
                points: points,
                outwardNormals: outwardNormals,
                textureCoordinates: textureLoop,
                contours: contours,
                physicalSize: physicalSize,
                preferredRadius: preferredRadius
            )
            smooth(&radii)
            guard radii.contains(where: { $0 > preferredRadius * 0.2 }) else {
                throw CardboardRimMeshGenerationError.invalidBevel
            }
            try appendSoftenedLoop(
                points: points,
                textureCoordinates: textureLoop,
                outwardNormals: outwardNormals,
                radii: radii,
                thickness: thickness,
                bevelSegments: bevelSegments,
                textureBounds: contours.textureBounds,
                physicalSize: physicalSize,
                geometry: &geometry
            )
            beveledLoops.append(
                BeveledContourLoop(
                    points: points,
                    textureCoordinates: textureLoop,
                    bevelRadii: radii
                )
            )
        }
        try geometry.validate()
        return SoftenedCardboardGeometry(geometry: geometry, loops: beveledLoops)
    }

    static func buildGeometry(
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>,
        limit: Int,
        thickness: Float
    ) throws -> CardboardRimGeometry {
        var geometry = CardboardRimGeometry()
        for sourceLoop in contours.outerLoops + contours.holeLoops {
            let textureLoop = resampled(sourceLoop, maximumCount: limit)
            let points = textureLoop.map {
                meshPoint($0, bounds: contours.textureBounds, size: physicalSize)
            }
            guard points.count >= 4 else {
                throw CardboardRimMeshGenerationError.insufficientVertices
            }
            let normals = try vertexNormals(for: points)
            var front: [UInt32] = []
            var back: [UInt32] = []
            for index in points.indices {
                front.append(geometry.append(
                    position: [points[index].x, points[index].y, thickness / 2],
                    normal: [normals[index].x, normals[index].y, 0],
                    uv: textureLoop[index]
                ))
                back.append(geometry.append(
                    position: [points[index].x, points[index].y, -thickness / 2],
                    normal: [normals[index].x, normals[index].y, 0],
                    uv: textureLoop[index]
                ))
            }
            appendStrip(front, back, geometry: &geometry)
        }
        try geometry.validate()
        return geometry
    }

    private static func appendSoftenedLoop(
        points: [SIMD2<Float>],
        textureCoordinates: [SIMD2<Float>],
        outwardNormals: [SIMD2<Float>],
        radii: [Float],
        thickness: Float,
        bevelSegments: Int,
        textureBounds: CGRect,
        physicalSize: SIMD2<Float>,
        geometry: inout CardboardRimGeometry
    ) throws {
        var frontLayers: [[UInt32]] = []
        var backLayers: [[UInt32]] = []
        for segment in 0...bevelSegments {
            let amount = Float(segment) / Float(bevelSegments)
            let angle = amount * .pi / 2
            let radialAmount = sin(angle)
            let depthAmount = cos(angle)
            var frontLayer: [UInt32] = []
            var backLayer: [UInt32] = []
            for index in points.indices {
                let radius = radii[index]
                let inset = -outwardNormals[index] * radius * radialAmount
                let uv = uvPoint(
                    points[index] + inset,
                    bounds: textureBounds,
                    size: physicalSize
                )
                let xyNormal = outwardNormals[index] * depthAmount
                frontLayer.append(geometry.append(
                    position: [
                        points[index].x + inset.x,
                        points[index].y + inset.y,
                        thickness / 2 - radius * depthAmount
                    ],
                    normal: [xyNormal.x, xyNormal.y, radialAmount],
                    uv: uv
                ))
                backLayer.append(geometry.append(
                    position: [
                        points[index].x + inset.x,
                        points[index].y + inset.y,
                        -thickness / 2 + radius * depthAmount
                    ],
                    normal: [xyNormal.x, xyNormal.y, -radialAmount],
                    uv: uv
                ))
            }
            frontLayers.append(frontLayer)
            backLayers.append(backLayer)
        }
        appendStrip(frontLayers[0], backLayers[0], geometry: &geometry)
        for layer in 0..<bevelSegments {
            appendStrip(frontLayers[layer + 1], frontLayers[layer], geometry: &geometry)
            appendStrip(backLayers[layer], backLayers[layer + 1], geometry: &geometry)
        }
    }

    private static func appendStrip(
        _ first: [UInt32],
        _ second: [UInt32],
        geometry: inout CardboardRimGeometry
    ) {
        for index in first.indices {
            let next = (index + 1) % first.count
            geometry.appendOrientedTriangle(first[index], second[index], first[next])
            geometry.appendOrientedTriangle(first[next], second[index], second[next])
        }
    }

    private static func locallySafeRadii(
        points: [SIMD2<Float>],
        outwardNormals: [SIMD2<Float>],
        textureCoordinates: [SIMD2<Float>],
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>,
        preferredRadius: Float
    ) -> [Float] {
        points.indices.map { index in
            var lower: Float = 0
            var upper = preferredRadius
            for _ in 0..<6 {
                let candidate = (lower + upper) / 2
                let insetPoint = points[index] - outwardNormals[index] * candidate
                let uv = uvPoint(insetPoint, bounds: contours.textureBounds, size: physicalSize)
                if isInside(uv, contours: contours)
                    && distanceToContours(uv, contours: contours, physicalSize: physicalSize)
                        >= candidate * 0.62 {
                    lower = candidate
                } else {
                    upper = candidate
                }
            }
            return lower < 0.00025 ? 0 : lower
        }
    }

    private static func smooth(_ radii: inout [Float]) {
        guard radii.count > 2 else { return }
        for _ in 0..<2 {
            let source = radii
            for index in radii.indices {
                let previous = source[(index - 1 + source.count) % source.count]
                let next = source[(index + 1) % source.count]
                radii[index] = min(source[index], (previous + source[index] * 2 + next) / 4)
            }
        }
    }

    private static func vertexNormals(for points: [SIMD2<Float>]) throws -> [SIMD2<Float>] {
        let segmentNormals = points.indices.map { index -> SIMD2<Float> in
            let direction = points[(index + 1) % points.count] - points[index]
            guard simd_length_squared(direction) > 1e-12 else { return .zero }
            let tangent = simd_normalize(direction)
            return [tangent.y, -tangent.x]
        }
        guard !segmentNormals.contains(where: { $0 == .zero }) else {
            throw CardboardRimMeshGenerationError.nonfiniteGeometry
        }
        return points.indices.map { index in
            let summed = segmentNormals[(index - 1 + points.count) % points.count]
                + segmentNormals[index]
            return simd_length_squared(summed) > 1e-12
                ? simd_normalize(summed)
                : segmentNormals[index]
        }
    }

    private static func meshPoint(
        _ uv: SIMD2<Float>,
        bounds: CGRect,
        size: SIMD2<Float>
    ) -> SIMD2<Float> {
        let localU = (uv.x - Float(bounds.minX)) / max(Float(bounds.width), 0.0001)
        let localV = (uv.y - Float(bounds.minY)) / max(Float(bounds.height), 0.0001)
        return [(localU - 0.5) * size.x, (0.5 - localV) * size.y]
    }

    private static func uvPoint(
        _ point: SIMD2<Float>,
        bounds: CGRect,
        size: SIMD2<Float>
    ) -> SIMD2<Float> {
        let localU = point.x / size.x + 0.5
        let localV = 0.5 - point.y / size.y
        return [
            Float(bounds.minX) + localU * Float(bounds.width),
            Float(bounds.minY) + localV * Float(bounds.height)
        ]
    }

    private static func isInside(
        _ point: SIMD2<Float>,
        contours: CutoutContourDescriptor
    ) -> Bool {
        contours.outerLoops.contains { contains(point, polygon: $0) }
            && !contours.holeLoops.contains { contains(point, polygon: $0) }
    }

    private static func contains(
        _ point: SIMD2<Float>,
        polygon: [SIMD2<Float>]
    ) -> Bool {
        var inside = false
        var previous = polygon[polygon.count - 1]
        for current in polygon {
            if (current.y > point.y) != (previous.y > point.y) {
                let crossing = (previous.x - current.x) * (point.y - current.y)
                    / (previous.y - current.y) + current.x
                if point.x < crossing { inside.toggle() }
            }
            previous = current
        }
        return inside
    }

    private static func distanceToContours(
        _ uv: SIMD2<Float>,
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>
    ) -> Float {
        let point = meshPoint(uv, bounds: contours.textureBounds, size: physicalSize)
        return (contours.outerLoops + contours.holeLoops).reduce(
            into: Float.greatestFiniteMagnitude
        ) { nearest, loop in
            let points = loop.map {
                meshPoint($0, bounds: contours.textureBounds, size: physicalSize)
            }
            for index in points.indices {
                let start = points[index]
                let end = points[(index + 1) % points.count]
                let edge = end - start
                let lengthSquared = simd_length_squared(edge)
                let amount = lengthSquared > 1e-12
                    ? min(max(simd_dot(point - start, edge) / lengthSquared, 0), 1)
                    : 0
                nearest = min(nearest, simd_length(point - (start + edge * amount)))
            }
        }
    }

    private static func resampled(
        _ points: [SIMD2<Float>],
        maximumCount: Int
    ) -> [SIMD2<Float>] {
        guard points.count > maximumCount else { return points }
        var cumulative: [Float] = [0]
        for index in points.indices {
            let next = points[(index + 1) % points.count]
            cumulative.append(cumulative.last! + simd_length(next - points[index]))
        }
        let perimeter = cumulative.last!
        guard perimeter > .ulpOfOne else { return [] }
        var segment = 0
        return (0..<maximumCount).map { sample in
            let target = perimeter * Float(sample) / Float(maximumCount)
            while segment + 1 < cumulative.count - 1, cumulative[segment + 1] < target {
                segment += 1
            }
            let start = points[segment % points.count]
            let end = points[(segment + 1) % points.count]
            let length = cumulative[segment + 1] - cumulative[segment]
            return start + (end - start) * (length > .ulpOfOne
                ? (target - cumulative[segment]) / length
                : 0)
        }
    }

    private struct CacheKey: Hashable {
        let contourFingerprint: UInt64
        let width: Int
        let height: Int
        let thickness: Int
    }
}

struct SoftenedCardboardGeometry {
    let geometry: CardboardRimGeometry
    let loops: [BeveledContourLoop]
}

struct CardboardRimGeometry {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var textureCoordinates: [SIMD2<Float>] = []
    var indices: [UInt32] = []

    mutating func append(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        uv: SIMD2<Float>
    ) -> UInt32 {
        let index = UInt32(positions.count)
        positions.append(position)
        normals.append(normal)
        textureCoordinates.append(uv)
        return index
    }

    mutating func appendOrientedTriangle(_ first: UInt32, _ second: UInt32, _ third: UInt32) {
        let edgeA = positions[Int(second)] - positions[Int(first)]
        let edgeB = positions[Int(third)] - positions[Int(first)]
        let faceNormal = simd_cross(edgeA, edgeB)
        let expected = normals[Int(first)] + normals[Int(second)] + normals[Int(third)]
        if simd_dot(faceNormal, expected) >= 0 {
            indices.append(contentsOf: [first, second, third])
        } else {
            indices.append(contentsOf: [first, third, second])
        }
    }

    func validate() throws {
        guard !indices.isEmpty,
              indices.count.isMultiple(of: 3),
              positions.count == normals.count,
              positions.count == textureCoordinates.count,
              positions.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
              normals.allSatisfy({
                  $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                      && abs(simd_length($0) - 1) < 0.001
              }),
              textureCoordinates.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              indices.allSatisfy({ Int($0) < positions.count }) else {
            throw CardboardRimMeshGenerationError.nonfiniteGeometry
        }
    }
}

enum CardboardRimMeshGenerationError: Error {
    case invalidContours
    case insufficientVertices
    case invalidBevel
    case nonfiniteGeometry
    case meshGenerationFailed(Error)
}
