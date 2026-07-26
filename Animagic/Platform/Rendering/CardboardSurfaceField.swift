//
//  CardboardSurfaceField.swift
//  AniMagic
//
//  Created by dimaswisodewo on 23/07/26.
//

import CoreGraphics
import Foundation
import simd

struct CardboardSurfaceField {
    static let encodedDistanceRange: Float = 0.016

    let width: Int
    let height: Int
    let values: [SIMD2<Float>]
    let maximumInteriorDistance: Float
    let fingerprint: UInt64

    func sample(_ uv: SIMD2<Float>) -> SIMD2<Float> {
        guard uv.x >= 0, uv.x <= 1, uv.y >= 0, uv.y <= 1 else { return .zero }
        let x = uv.x * Float(width - 1)
        let y = uv.y * Float(height - 1)
        let minX = Int(floor(x))
        let minY = Int(floor(y))
        let maxX = min(minX + 1, width - 1)
        let maxY = min(minY + 1, height - 1)
        let amountX = x - Float(minX)
        let amountY = y - Float(minY)
        let top = Self.mix(
            values[minY * width + minX],
            values[minY * width + maxX],
            amountX
        )
        let bottom = Self.mix(
            values[maxY * width + minX],
            values[maxY * width + maxX],
            amountX
        )
        return Self.mix(top, bottom, amountY)
    }

    func makeImage() -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for (index, value) in values.enumerated() {
            let offset = index * 4
            pixels[offset] = UInt8(
                min(max(value.x / Self.encodedDistanceRange, 0), 1) * 255
            )
            pixels[offset + 1] = UInt8(
                min(max(value.y / Self.encodedDistanceRange, 0), 1) * 255
            )
            pixels[offset + 2] = 0
            pixels[offset + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    static func generate(
        loops: [BeveledContourLoop],
        contours: CutoutContourDescriptor,
        physicalSize: SIMD2<Float>,
        maximumDimension: Int = 256
    ) throws -> Self {
        guard !loops.isEmpty, physicalSize.x > 0, physicalSize.y > 0 else {
            throw CardboardRimMeshGenerationError.invalidContours
        }
        let aspect = physicalSize.x / physicalSize.y
        let width: Int
        let height: Int
        if aspect >= 1 {
            width = maximumDimension
            height = max(Int((Float(maximumDimension) / aspect).rounded()), 2)
        } else {
            height = maximumDimension
            width = max(Int((Float(maximumDimension) * aspect).rounded()), 2)
        }

        var values = [SIMD2<Float>](repeating: .zero, count: width * height)
        var maximumInteriorDistance: Float = 0
        for y in 0..<height {
            let v = Float(y) / Float(height - 1)
            for x in 0..<width {
                let u = Float(x) / Float(width - 1)
                let uv = SIMD2<Float>(u, v)
                guard contains(uv, contours: contours) else { continue }
                let point = meshPoint(uv, bounds: contours.textureBounds, size: physicalSize)
                var nearestDistance = Float.greatestFiniteMagnitude
                var nearestRadius: Float = 0
                for loop in loops {
                    for index in loop.points.indices {
                        let next = (index + 1) % loop.points.count
                        let start = loop.points[index]
                        let end = loop.points[next]
                        let edge = end - start
                        let lengthSquared = simd_length_squared(edge)
                        let amount = lengthSquared > 1e-12
                            ? min(max(simd_dot(point - start, edge) / lengthSquared, 0), 1)
                            : 0
                        let nearest = start + edge * amount
                        let distance = simd_length(point - nearest)
                        if distance < nearestDistance {
                            nearestDistance = distance
                            nearestRadius = mix(
                                loop.bevelRadii[index],
                                loop.bevelRadii[next],
                                amount
                            )
                        }
                    }
                }
                guard nearestDistance.isFinite else { continue }
                values[y * width + x] = [nearestDistance, nearestRadius]
                maximumInteriorDistance = max(maximumInteriorDistance, nearestDistance)
            }
        }

        var hash = contours.fingerprint
        hash ^= UInt64(width)
        hash &*= 1_099_511_628_211
        hash ^= UInt64(height)
        hash &*= 1_099_511_628_211
        for loop in loops {
            for radius in loop.bevelRadii {
                hash ^= UInt64(radius.bitPattern)
                hash &*= 1_099_511_628_211
            }
        }
        return Self(
            width: width,
            height: height,
            values: values,
            maximumInteriorDistance: maximumInteriorDistance,
            fingerprint: hash
        )
    }

    private static func contains(
        _ point: SIMD2<Float>,
        contours: CutoutContourDescriptor
    ) -> Bool {
        let insideOuter = contours.outerLoops.contains { contains(point, polygon: $0) }
        let insideHole = contours.holeLoops.contains { contains(point, polygon: $0) }
        return insideOuter && !insideHole
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

    private static func meshPoint(
        _ uv: SIMD2<Float>,
        bounds: CGRect,
        size: SIMD2<Float>
    ) -> SIMD2<Float> {
        let localU = (uv.x - Float(bounds.minX)) / max(Float(bounds.width), 0.0001)
        let localV = (uv.y - Float(bounds.minY)) / max(Float(bounds.height), 0.0001)
        return [(localU - 0.5) * size.x, (0.5 - localV) * size.y]
    }

    private static func mix(
        _ lower: SIMD2<Float>,
        _ upper: SIMD2<Float>,
        _ amount: Float
    ) -> SIMD2<Float> {
        lower + (upper - lower) * amount
    }

    private static func mix(_ lower: Float, _ upper: Float, _ amount: Float) -> Float {
        lower + (upper - lower) * amount
    }
}

struct BeveledContourLoop {
    let points: [SIMD2<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let bevelRadii: [Float]
}
