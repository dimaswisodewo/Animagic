//
//  CardboardContourValidation.swift
//  AniMagic
//
//  Created by dimaswisodewo on 23/07/26.
//

import CoreGraphics
import Foundation
import RealityKit
import simd

enum CutoutRenderQuality: Int, CaseIterable {
    case economy = 12
    case balanced = 20
    case hero = 32
}

@main
enum CardboardContourValidation {
    static func main() {
        let fixtures: [(String, AlphaFixture, (CutoutContourDescriptor?) -> Bool)] = [
            ("fully transparent", .empty, { $0 == nil }),
            ("fully opaque", .opaque, { $0?.outerLoops.count == 1 }),
            ("internal hole", .hole, { $0?.outerLoops.count == 1 && $0?.holeLoops.count == 1 }),
            ("tiny speckle", .speckle, { $0?.outerLoops.count == 1 && $0?.holeLoops.isEmpty == true }),
            ("disconnected island", .islands, { ($0?.outerLoops.count ?? 0) >= 2 }),
            ("diagonal contact", .diagonal, { ($0?.outerLoops.isEmpty == false) }),
            ("thin appendage", .thinAppendage, { descriptor in
                guard let points = descriptor?.outerLoops.first else { return false }
                return points.contains { $0.x > 0.80 }
            })
        ]

        var failures: [String] = []
        for (name, fixture, accepts) in fixtures {
            guard let image = fixture.image else {
                failures.append("\(name): image creation failed")
                continue
            }
            let first = CutoutContourExtractor.extract(from: image)
            let second = CutoutContourExtractor.extract(from: image)
            if !accepts(first) {
                failures.append(
                    "\(name): unexpected contour result "
                        + "(outer: \(first?.outerLoops.count ?? 0), holes: \(first?.holeLoops.count ?? 0))"
                )
            }
            if first?.fingerprint != second?.fingerprint {
                failures.append("\(name): repeated extraction was not deterministic")
            }
            if let first {
                validateGeometry(first, fixtureName: name, failures: &failures)
            }
        }

        if failures.isEmpty {
            print("Cardboard contour validation passed \(fixtures.count) deterministic fixtures.")
        } else {
            for failure in failures {
                fputs("error: \(failure)\n", stderr)
            }
            exit(1)
        }
    }

    private static func validateGeometry(
        _ contours: CutoutContourDescriptor,
        fixtureName: String,
        failures: inout [String]
    ) {
        let thickness: Float = 0.00525
        for limit in [64, 128, 256] {
            do {
                let geometry = try CardboardRimMeshGenerator.buildGeometry(
                    contours: contours,
                    physicalSize: [0.35, 0.24],
                    limit: limit,
                    thickness: thickness
                )
                let validIndices = geometry.indices.allSatisfy {
                    Int($0) < geometry.positions.count
                }
                let validDepth = geometry.positions.allSatisfy {
                    abs(abs($0.z) - thickness / 2) < 0.000_001
                }
                let validNormals = geometry.normals.allSatisfy {
                    abs(simd_length($0) - 1) < 0.000_1 && abs($0.z) < 0.000_001
                }
                let validUVs = geometry.textureCoordinates.allSatisfy {
                    $0.x.isFinite && $0.y.isFinite
                }
                let validWinding = stride(
                    from: 0,
                    to: geometry.indices.count,
                    by: 3
                ).allSatisfy { index in
                    let first = Int(geometry.indices[index])
                    let second = Int(geometry.indices[index + 1])
                    let third = Int(geometry.indices[index + 2])
                    let edgeA = geometry.positions[second] - geometry.positions[first]
                    let edgeB = geometry.positions[third] - geometry.positions[first]
                    let faceNormal = simd_cross(edgeA, edgeB)
                    return simd_dot(faceNormal, geometry.normals[first]) > 0
                }
                if geometry.indices.isEmpty
                    || !geometry.indices.count.isMultiple(of: 6)
                    || !validIndices
                    || !validDepth
                    || !validNormals
                    || !validUVs
                    || !validWinding {
                    failures.append(
                        "\(fixtureName): invalid rim geometry at \(limit)-vertex quality"
                    )
                }
            } catch {
                failures.append(
                    "\(fixtureName): rim geometry failed at \(limit)-vertex quality: \(error)"
                )
            }
        }
        validateSoftenedGeometry(
            contours,
            fixtureName: fixtureName,
            thickness: thickness,
            failures: &failures
        )
    }

    private static func validateSoftenedGeometry(
        _ contours: CutoutContourDescriptor,
        fixtureName: String,
        thickness: Float,
        failures: inout [String]
    ) {
        let preferredRadius: Float = 0.002
        do {
            let softened = try CardboardRimMeshGenerator.buildSoftenedGeometry(
                contours: contours,
                physicalSize: [0.35, 0.24],
                limit: 256,
                thickness: thickness,
                preferredRadius: preferredRadius,
                bevelSegments: 4
            )
            let geometry = softened.geometry
            let validIndices = geometry.indices.allSatisfy {
                Int($0) < geometry.positions.count
            }
            let validDepth = geometry.positions.allSatisfy {
                $0.z >= -thickness / 2 - 0.000_001
                    && $0.z <= thickness / 2 + 0.000_001
            }
            let validNormals = geometry.normals.allSatisfy {
                abs(simd_length($0) - 1) < 0.000_1
            }
            let validRadii = softened.loops.flatMap(\.bevelRadii).allSatisfy {
                $0 >= 0 && $0 <= preferredRadius + 0.000_001
            }
            let field = try CardboardSurfaceField.generate(
                loops: softened.loops,
                contours: contours,
                physicalSize: [0.35, 0.24],
                maximumDimension: 96
            )
            let validField = field.values.count == field.width * field.height
                && field.maximumInteriorDistance > 0
                && field.values.allSatisfy {
                    $0.x.isFinite && $0.y.isFinite
                        && $0.x >= 0 && $0.y >= 0
                }
                && field.makeImage() != nil
            if geometry.indices.isEmpty
                || !validIndices
                || !validDepth
                || !validNormals
                || !validRadii
                || !validField {
                failures.append("\(fixtureName): invalid softened cardboard geometry")
            }
        } catch {
            failures.append("\(fixtureName): softened cardboard geometry failed: \(error)")
        }
    }
}

private enum AlphaFixture {
    case empty
    case opaque
    case hole
    case speckle
    case islands
    case diagonal
    case thinAppendage

    private static let size = 96

    var image: CGImage? {
        let width = Self.size
        let height = Self.size
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        func fill(_ rect: CGRect, alpha: UInt8 = 255) {
            let xRange = max(Int(rect.minX), 0)..<min(Int(rect.maxX), width)
            let yRange = max(Int(rect.minY), 0)..<min(Int(rect.maxY), height)
            for y in yRange {
                for x in xRange {
                    let offset = (y * width + x) * 4
                    pixels[offset] = alpha
                    pixels[offset + 1] = alpha
                    pixels[offset + 2] = alpha
                    pixels[offset + 3] = alpha
                }
            }
        }

        switch self {
        case .empty:
            break
        case .opaque:
            fill(CGRect(x: 0, y: 0, width: width, height: height))
        case .hole:
            fill(CGRect(x: 12, y: 12, width: 72, height: 72))
            fill(CGRect(x: 34, y: 34, width: 28, height: 28), alpha: 0)
        case .speckle:
            fill(CGRect(x: 12, y: 12, width: 72, height: 72))
            fill(CGRect(x: 45, y: 45, width: 1, height: 1), alpha: 0)
        case .islands:
            fill(CGRect(x: 8, y: 18, width: 58, height: 58))
            fill(CGRect(x: 76, y: 38, width: 12, height: 12))
        case .diagonal:
            fill(CGRect(x: 12, y: 12, width: 34, height: 34))
            fill(CGRect(x: 46, y: 46, width: 34, height: 34))
        case .thinAppendage:
            fill(CGRect(x: 14, y: 22, width: 52, height: 52))
            fill(CGRect(x: 66, y: 46, width: 22, height: 4))
        }

        let provider = CGDataProvider(data: Data(pixels) as CFData)
        return provider.flatMap {
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                ),
                provider: $0,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }
}
