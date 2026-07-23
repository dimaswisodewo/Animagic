//
//  CutoutContourExtraction.swift
//  AniMagic
//
//  Created by dimaswisodewo on 23/07/26.
//

import CoreGraphics
import Foundation
import simd

struct CutoutContourDescriptor {
    let outerLoops: [[SIMD2<Float>]]
    let holeLoops: [[SIMD2<Float>]]
    let textureBounds: CGRect

    func mapped(to textureBounds: CGRect) -> Self {
        Self(
            outerLoops: outerLoops,
            holeLoops: holeLoops,
            textureBounds: textureBounds
        )
    }

    var fingerprint: UInt64 {
        var hash = Self.fnvOffset
        for (kind, loops) in [(UInt64(0), outerLoops), (UInt64(1), holeLoops)] {
            Self.combine(kind, into: &hash)
            for loop in loops {
                Self.combine(UInt64(loop.count), into: &hash)
                for point in loop {
                    Self.combine(UInt64(point.x.bitPattern), into: &hash)
                    Self.combine(UInt64(point.y.bitPattern), into: &hash)
                }
            }
        }
        for component in [textureBounds.minX, textureBounds.minY, textureBounds.width, textureBounds.height] {
            Self.combine(UInt64(Float(component).bitPattern), into: &hash)
        }
        return hash
    }

    fileprivate static let fnvOffset: UInt64 = 14_695_981_039_346_656_037
    fileprivate static let fnvPrime: UInt64 = 1_099_511_628_211

    private static func combine(_ value: UInt64, into hash: inout UInt64) {
        hash ^= value
        hash &*= fnvPrime
    }
}

enum CutoutContourExtractor {
    private static let alphaThreshold: Float = 12
    private static let maximumDimension = 256
    private static let simplificationTolerance: Float = 0.75
    private static let closureTolerance: Float = 1.05
    private static var cache: [UInt64: CutoutContourDescriptor] = [:]
    private static let cacheLock = NSLock()

    static func extract(from image: CGImage) -> CutoutContourDescriptor? {
        guard let mask = AlphaMask(image: image, maximumDimension: maximumDimension) else {
            return nil
        }
        let fingerprint = mask.fingerprint
        cacheLock.lock()
        let cached = cache[fingerprint]
        cacheLock.unlock()
        if let cached {
            return cached
        }

        guard let descriptor = extract(from: mask) else { return nil }
        cacheLock.lock()
        cache[fingerprint] = descriptor
        cacheLock.unlock()
        return descriptor
    }

    private static func extract(from mask: AlphaMask) -> CutoutContourDescriptor? {
        let segments = marchingSquares(mask)
        let rawLoops = joinedLoops(from: segments)
        let loops = rawLoops.compactMap { rawLoop -> [SIMD2<Float>]? in
            guard rawLoop.count >= 8 else { return nil }
            var simplified = simplifyClosed(rawLoop, tolerance: simplificationTolerance)
            guard simplified.count >= 4, abs(signedArea(simplified)) > 0.5 else { return nil }
            simplified = cap(simplified, at: 256)
            return simplified
        }
        guard !loops.isEmpty else { return nil }

        let records = loops.enumerated().map { index, loop in
            LoopRecord(
                index: index,
                points: loop,
                absoluteArea: abs(signedArea(loop)),
                probe: loop[0]
            )
        }
        let depths = records.map { record in
            records.reduce(into: 0) { depth, candidate in
                guard candidate.index != record.index,
                      candidate.absoluteArea > record.absoluteArea,
                      contains(record.probe, in: candidate.points) else { return }
                depth += 1
            }
        }

        let outerRecords = records.enumerated()
            .filter { depths[$0.offset].isMultiple(of: 2) }
            .map(\.element)
        guard let largestOuterArea = outerRecords.map(\.absoluteArea).max(),
              largestOuterArea > 0 else { return nil }
        let retainedOuters = outerRecords
            .filter { $0.absoluteArea >= largestOuterArea * 0.005 }
            .sorted { stableLoopOrder($0, $1) }
        let retainedOuterIndices = Set(retainedOuters.map(\.index))

        let retainedHoles = records.enumerated().compactMap { offset, record -> LoopRecord? in
            guard !depths[offset].isMultiple(of: 2) else { return nil }
            let enclosingOuter = retainedOuters
                .filter { $0.absoluteArea > record.absoluteArea && contains(record.probe, in: $0.points) }
                .min { $0.absoluteArea < $1.absoluteArea }
            guard let enclosingOuter,
                  retainedOuterIndices.contains(enclosingOuter.index),
                  record.absoluteArea >= enclosingOuter.absoluteArea * 0.0025 else { return nil }
            return record
        }.sorted { stableLoopOrder($0, $1) }

        let scale = SIMD2<Float>(
            Float(max(mask.contentWidth - 1, 1)),
            Float(max(mask.contentHeight - 1, 1))
        )
        let outerLoops = retainedOuters.map {
            normalized(
                $0.points.map { $0 - SIMD2<Float>(repeating: 1) },
                scale: scale,
                wantsCounterclockwiseInMesh: true
            )
        }
        let holeLoops = retainedHoles.map {
            normalized(
                $0.points.map { $0 - SIMD2<Float>(repeating: 1) },
                scale: scale,
                wantsCounterclockwiseInMesh: false
            )
        }
        guard !outerLoops.isEmpty else { return nil }
        let allOuterPoints = outerLoops.flatMap { $0 }
        guard let minX = allOuterPoints.map(\.x).min(),
              let minY = allOuterPoints.map(\.y).min(),
              let maxX = allOuterPoints.map(\.x).max(),
              let maxY = allOuterPoints.map(\.y).max(),
              maxX > minX, maxY > minY else { return nil }
        return CutoutContourDescriptor(
            outerLoops: outerLoops,
            holeLoops: holeLoops,
            textureBounds: CGRect(
                x: CGFloat(minX),
                y: CGFloat(minY),
                width: CGFloat(maxX - minX),
                height: CGFloat(maxY - minY)
            )
        )
    }

    private static func marchingSquares(_ mask: AlphaMask) -> [Segment] {
        guard mask.width > 1, mask.height > 1 else { return [] }
        var result: [Segment] = []
        result.reserveCapacity(mask.width * mask.height)
        for y in 0..<(mask.height - 1) {
            for x in 0..<(mask.width - 1) {
                let topLeft = mask[x, y]
                let topRight = mask[x + 1, y]
                let bottomRight = mask[x + 1, y + 1]
                let bottomLeft = mask[x, y + 1]
                let values = [topLeft, topRight, bottomRight, bottomLeft]
                let code = values.enumerated().reduce(into: 0) { value, sample in
                    if sample.element > alphaThreshold { value |= 1 << sample.offset }
                }
                guard code != 0, code != 15 else { continue }
                let origin = SIMD2<Float>(Float(x), Float(y))
                let crossings: [Int: SIMD2<Float>] = [
                    0: origin + interpolate([0, 0], [1, 0], topLeft, topRight),
                    1: origin + interpolate([1, 0], [1, 1], topRight, bottomRight),
                    2: origin + interpolate([1, 1], [0, 1], bottomRight, bottomLeft),
                    3: origin + interpolate([0, 1], [0, 0], bottomLeft, topLeft)
                ]
                let pairs: [(Int, Int)]
                switch code {
                case 1, 14: pairs = [(3, 0)]
                case 2, 13: pairs = [(0, 1)]
                case 3, 12: pairs = [(3, 1)]
                case 4, 11: pairs = [(1, 2)]
                case 6, 9: pairs = [(0, 2)]
                case 7, 8: pairs = [(3, 2)]
                case 5:
                    pairs = ((topLeft + topRight + bottomRight + bottomLeft) * 0.25) > alphaThreshold
                        ? [(0, 1), (2, 3)]
                        : [(3, 0), (1, 2)]
                case 10:
                    pairs = ((topLeft + topRight + bottomRight + bottomLeft) * 0.25) > alphaThreshold
                        ? [(3, 0), (1, 2)]
                        : [(0, 1), (2, 3)]
                default: pairs = []
                }
                for pair in pairs {
                    if let start = crossings[pair.0], let end = crossings[pair.1] {
                        result.append(Segment(start: start, end: end))
                    }
                }
            }
        }
        return result
    }

    private static func joinedLoops(from segments: [Segment]) -> [[SIMD2<Float>]] {
        var unused = segments
        var loops: [[SIMD2<Float>]] = []
        while let first = unused.popLast() {
            var points = [first.start, first.end]
            var closed = false
            while !unused.isEmpty {
                let current = points[points.count - 1]
                if points.count >= 8, distance(current, points[0]) <= closureTolerance {
                    closed = true
                    break
                }
                guard let match = unused.enumerated().min(by: {
                    min(distance(current, $0.element.start), distance(current, $0.element.end))
                        < min(distance(current, $1.element.start), distance(current, $1.element.end))
                }), min(
                    distance(current, match.element.start),
                    distance(current, match.element.end)
                ) <= closureTolerance else { break }
                let segment = unused.remove(at: match.offset)
                points.append(
                    distance(current, segment.start) <= distance(current, segment.end)
                        ? segment.end
                        : segment.start
                )
            }
            if closed {
                points.removeLast()
                loops.append(points)
            }
        }
        return loops
    }

    private static func interpolate(
        _ start: SIMD2<Float>,
        _ end: SIMD2<Float>,
        _ startAlpha: Float,
        _ endAlpha: Float
    ) -> SIMD2<Float> {
        let delta = endAlpha - startAlpha
        let amount = abs(delta) < .ulpOfOne
            ? 0.5
            : min(max((alphaThreshold - startAlpha) / delta, 0), 1)
        return start + (end - start) * amount
    }

    private static func simplifyClosed(
        _ points: [SIMD2<Float>],
        tolerance: Float
    ) -> [SIMD2<Float>] {
        guard points.count > 4 else { return points }
        let anchor = points.indices.max {
            distance(points[0], points[$0]) < distance(points[0], points[$1])
        } ?? points.count / 2
        let firstHalf = rdp(Array(points[0...anchor]), tolerance: tolerance)
        let secondHalf = rdp(Array(points[anchor...] + points[0...0]), tolerance: tolerance)
        return Array(firstHalf.dropLast()) + Array(secondHalf.dropLast())
    }

    private static func rdp(
        _ points: [SIMD2<Float>],
        tolerance: Float
    ) -> [SIMD2<Float>] {
        guard points.count > 2 else { return points }
        var furthestIndex = 0
        var furthestDistance: Float = 0
        for index in 1..<(points.count - 1) {
            let candidateDistance = perpendicularDistance(
                points[index],
                lineStart: points[0],
                lineEnd: points[points.count - 1]
            )
            if candidateDistance > furthestDistance {
                furthestDistance = candidateDistance
                furthestIndex = index
            }
        }
        guard furthestDistance > tolerance else {
            return [points[0], points[points.count - 1]]
        }
        let left = rdp(Array(points[0...furthestIndex]), tolerance: tolerance)
        let right = rdp(Array(points[furthestIndex...]), tolerance: tolerance)
        return Array(left.dropLast()) + right
    }

    private static func perpendicularDistance(
        _ point: SIMD2<Float>,
        lineStart: SIMD2<Float>,
        lineEnd: SIMD2<Float>
    ) -> Float {
        let line = lineEnd - lineStart
        let lengthSquared = simd_length_squared(line)
        guard lengthSquared > .ulpOfOne else { return distance(point, lineStart) }
        let amount = min(max(simd_dot(point - lineStart, line) / lengthSquared, 0), 1)
        return distance(point, lineStart + line * amount)
    }

    private static func cap(_ points: [SIMD2<Float>], at limit: Int) -> [SIMD2<Float>] {
        guard points.count > limit else { return points }
        return (0..<limit).map { points[$0 * points.count / limit] }
    }

    private static func normalized(
        _ points: [SIMD2<Float>],
        scale: SIMD2<Float>,
        wantsCounterclockwiseInMesh: Bool
    ) -> [SIMD2<Float>] {
        let normalizedPoints = points.map { point in
            SIMD2<Float>(
                min(max(point.x / scale.x, 0), 1),
                min(max(point.y / scale.y, 0), 1)
            )
        }
        var result: [SIMD2<Float>] = []
        result.reserveCapacity(normalizedPoints.count)
        for point in normalizedPoints where result.last.map({ distance($0, point) > 1e-6 }) ?? true {
            result.append(point)
        }
        if result.count > 1, distance(result[0], result[result.count - 1]) <= 1e-6 {
            result.removeLast()
        }
        let isCounterclockwiseInMesh = signedArea(result) < 0
        if isCounterclockwiseInMesh != wantsCounterclockwiseInMesh {
            result.reverse()
        }
        if let start = result.indices.min(by: {
            result[$0].y == result[$1].y
                ? result[$0].x < result[$1].x
                : result[$0].y < result[$1].y
        }) {
            result = Array(result[start...] + result[..<start])
        }
        return result
    }

    private static func signedArea(_ points: [SIMD2<Float>]) -> Float {
        points.indices.reduce(into: Float.zero) { area, index in
            let next = points[(index + 1) % points.count]
            area += points[index].x * next.y - next.x * points[index].y
        } * 0.5
    }

    private static func contains(_ point: SIMD2<Float>, in polygon: [SIMD2<Float>]) -> Bool {
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

    private static func stableLoopOrder(_ lhs: LoopRecord, _ rhs: LoopRecord) -> Bool {
        if lhs.absoluteArea != rhs.absoluteArea { return lhs.absoluteArea > rhs.absoluteArea }
        if lhs.probe.y != rhs.probe.y { return lhs.probe.y < rhs.probe.y }
        return lhs.probe.x < rhs.probe.x
    }

    private static func distance(_ lhs: SIMD2<Float>, _ rhs: SIMD2<Float>) -> Float {
        simd_length(lhs - rhs)
    }

    private struct Segment {
        let start: SIMD2<Float>
        let end: SIMD2<Float>
    }

    private struct LoopRecord {
        let index: Int
        let points: [SIMD2<Float>]
        let absoluteArea: Float
        let probe: SIMD2<Float>
    }

    private struct AlphaMask {
        let width: Int
        let height: Int
        let contentWidth: Int
        let contentHeight: Int
        let samples: [UInt8]
        let fingerprint: UInt64

        init?(image: CGImage, maximumDimension: Int) {
            guard image.width > 0, image.height > 0 else { return nil }
            let scale = min(1, CGFloat(maximumDimension) / CGFloat(max(image.width, image.height)))
            contentWidth = max(Int((CGFloat(image.width) * scale).rounded()), 2)
            contentHeight = max(Int((CGFloat(image.height) * scale).rounded()), 2)
            width = contentWidth + 2
            height = contentHeight + 2
            var rgba = [UInt8](repeating: 0, count: contentWidth * contentHeight * 4)
            guard let context = CGContext(
                data: &rgba,
                width: contentWidth,
                height: contentHeight,
                bitsPerComponent: 8,
                bytesPerRow: contentWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
            let contentSamples = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
            guard contentSamples.contains(where: { $0 > UInt8(alphaThreshold) }) else { return nil }
            var paddedSamples = [UInt8](repeating: 0, count: width * height)
            for y in 0..<contentHeight {
                let sourceStart = y * contentWidth
                let destinationStart = (y + 1) * width + 1
                paddedSamples.replaceSubrange(
                    destinationStart..<(destinationStart + contentWidth),
                    with: contentSamples[sourceStart..<(sourceStart + contentWidth)]
                )
            }
            samples = paddedSamples
            var hash = CutoutContourDescriptor.fnvOffset
            for byte in contentSamples {
                hash ^= UInt64(byte)
                hash &*= CutoutContourDescriptor.fnvPrime
            }
            hash ^= UInt64(contentWidth)
            hash &*= CutoutContourDescriptor.fnvPrime
            hash ^= UInt64(contentHeight)
            fingerprint = hash
        }

        subscript(x: Int, y: Int) -> Float {
            Float(samples[y * width + x])
        }
    }
}
