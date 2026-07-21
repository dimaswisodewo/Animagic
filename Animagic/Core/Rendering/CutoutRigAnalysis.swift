//
//  CutoutRigAnalysis.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 21/07/26.
//

import CoreGraphics
import Foundation

struct CutoutRigDescriptor: Equatable {
    let visibleBounds: CGRect
    let supportContacts: [CGPoint]
    let defaultFacing: Float
    let facingConfidence: Float
}

enum CutoutRigAnalyzer {
    static func analyze(_ image: CGImage) -> CutoutRigDescriptor {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return fallback }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return fallback }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        return analyzeAlpha(alpha, width: width, height: height)
    }

    static func analyzeAlpha(_ alpha: [UInt8], width: Int, height: Int) -> CutoutRigDescriptor {
        guard width > 0, height > 0, alpha.count == width * height else { return fallback }
        var minX = width, minY = height, maxX = -1, maxY = -1
        var columnMass = [Int](repeating: 0, count: width)
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 12 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                columnMass[x] += 1
            }
        }
        guard maxX >= minX, maxY >= minY else { return fallback }
        let padding = 2
        minX = max(minX - padding, 0); minY = max(minY - padding, 0)
        maxX = min(maxX + padding, width - 1); maxY = min(maxY + padding, height - 1)
        let bounds = CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(maxX - minX + 1) / CGFloat(width),
            height: CGFloat(maxY - minY + 1) / CGFloat(height)
        )
        let span = max(maxX - minX + 1, 1)
        let endWidth = max(span / 4, 1)
        let leftMass = columnMass[minX...min(minX + endWidth, maxX)].reduce(0, +)
        let rightMass = columnMass[max(maxX - endWidth, minX)...maxX].reduce(0, +)
        let total = max(leftMass + rightMass, 1)
        let confidence = Float(abs(leftMass - rightMass)) / Float(total)
        let facing: Float = rightMass >= leftMass ? 1 : -1

        let contactBandStart = max(maxY - max((maxY - minY) / 8, 1), minY)
        var contactColumns: [Int] = []
        for x in minX...maxX where (contactBandStart...maxY).contains(where: { alpha[$0 * width + x] > 12 }) {
            contactColumns.append(x)
        }
        let contacts: [CGPoint]
        if let first = contactColumns.first, let last = contactColumns.last {
            contacts = [first, last].map {
                CGPoint(x: CGFloat($0) / CGFloat(width), y: CGFloat(maxY) / CGFloat(height))
            }
        } else {
            contacts = []
        }
        return CutoutRigDescriptor(
            visibleBounds: bounds,
            supportContacts: contacts,
            defaultFacing: confidence >= 0.08 ? facing : 1,
            facingConfidence: confidence
        )
    }

    private static let fallback = CutoutRigDescriptor(
        visibleBounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        supportContacts: [],
        defaultFacing: 1,
        facingConfidence: 0
    )
}
