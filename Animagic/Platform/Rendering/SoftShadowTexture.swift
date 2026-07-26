//
//  SoftShadowTexture.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import UIKit

enum SoftShadowTexture {
    static let image: UIImage = {
        let size = CGSize(width: 256, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.black.withAlphaComponent(0.3).cgColor,
                UIColor.black.withAlphaComponent(0.13).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: [0, 0.46, 1]
            ) else {
                return
            }

            context.saveGState()
            context.scaleBy(x: 1, y: 0.5)
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 128, y: 128),
                startRadius: 0,
                endCenter: CGPoint(x: 128, y: 128),
                endRadius: 128,
                options: [.drawsAfterEndLocation]
            )
            context.restoreGState()
        }
    }()
}
