//
//  RenderingExtensions.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import UIKit
import simd

extension UIImage {
    func mirroredHorizontally(aroundNormalizedX axis: CGFloat = 0.5) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: size.width * axis * 2, y: 0)
            cgContext.scaleBy(x: -1, y: 1)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        [columns.3.x, columns.3.y, columns.3.z]
    }

    var right: SIMD3<Float> {
        normalize([columns.0.x, columns.0.y, columns.0.z])
    }

    var up: SIMD3<Float> {
        normalize([columns.1.x, columns.1.y, columns.1.z])
    }

    var forward: SIMD3<Float> {
        normalize([columns.2.x, columns.2.y, columns.2.z])
    }

    func yawFacingCamera(from position: SIMD3<Float>) -> Float {
        let direction = normalize(translation - position)
        return atan2(direction.x, direction.z)
    }
}
