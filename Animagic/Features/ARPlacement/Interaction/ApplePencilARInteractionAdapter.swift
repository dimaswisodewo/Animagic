//
//  ApplePencilARInteractionAdapter.swift
//  AniMagic
//
//  Created by dimaswisodewo on 21/07/26.
//

import RealityKit
import UIKit

@MainActor
final class ApplePencilARInteractionAdapter: NSObject, UIPencilInteractionDelegate {
    private weak var arView: ARView?
    private weak var controller: NewARSceneController?
    private var hoverRecognizer: UIHoverGestureRecognizer?
    private var pencilInteraction: UIPencilInteraction?
    private var didAttemptCurrentSqueeze = false

    init(controller: NewARSceneController) {
        self.controller = controller
    }

    func attach(to arView: ARView) {
        self.arView = arView

        let hoverRecognizer = UIHoverGestureRecognizer(
            target: self,
            action: #selector(handleHover(_:))
        )
        hoverRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        arView.addGestureRecognizer(hoverRecognizer)
        self.hoverRecognizer = hoverRecognizer

        let pencilInteraction = UIPencilInteraction(delegate: self)
        arView.addInteraction(pencilInteraction)
        self.pencilInteraction = pencilInteraction
    }

    func detach() {
        controller?.cancelPencilRotation()
        controller?.clearPencilHoverTarget()
        if let hoverRecognizer {
            arView?.removeGestureRecognizer(hoverRecognizer)
        }
        if let pencilInteraction {
            arView?.removeInteraction(pencilInteraction)
        }
        hoverRecognizer = nil
        pencilInteraction = nil
        arView = nil
    }

    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        guard let arView, let controller, controller.isInteractionReady else { return }

        switch recognizer.state {
        case .began, .changed:
            guard !controller.isPencilRotating else { return }
            controller.setPencilHoverTarget(at: recognizer.location(in: arView))
        case .ended, .cancelled, .failed:
            guard !controller.isPencilRotating else { return }
            controller.clearPencilHoverTarget()
        default:
            break
        }
    }

    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        guard let controller, controller.isInteractionReady else { return }

        switch squeeze.phase {
        case .began:
            didAttemptCurrentSqueeze = true
            beginRotation(using: squeeze, controller: controller)
        case .changed:
            if !controller.isPencilRotating, !didAttemptCurrentSqueeze {
                didAttemptCurrentSqueeze = true
                beginRotation(using: squeeze, controller: controller)
            }
            if let rollAngle = squeeze.hoverPose?.rollAngle {
                controller.updatePencilRotation(rollAngle: Float(rollAngle))
            }
        case .ended:
            if !controller.isPencilRotating, !didAttemptCurrentSqueeze {
                beginRotation(using: squeeze, controller: controller)
            }
            controller.commitPencilRotation()
            didAttemptCurrentSqueeze = false
        case .cancelled:
            controller.cancelPencilRotation()
            didAttemptCurrentSqueeze = false
        @unknown default:
            controller.cancelPencilRotation()
            didAttemptCurrentSqueeze = false
        }
    }

    private func beginRotation(
        using squeeze: UIPencilInteraction.Squeeze,
        controller: NewARSceneController
    ) {
        let point = squeeze.hoverPose?.location
        let rollAngle = Float(squeeze.hoverPose?.rollAngle ?? 0)
        controller.beginPencilRotation(at: point, rollAngle: rollAngle)
    }
}

enum PencilHoverIndicatorFactory {
    static func make(radius: Float) -> Entity {
        makeIndicator(
            named: "pencil_hover_indicator",
            radius: radius,
            textureImage: makeTexture()
        )
    }

    private static func makeTexture() -> CGImage? {
        let size = CGSize(width: 256, height: 256)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.24).cgColor)
        context.setLineWidth(22)
        context.strokeEllipse(in: CGRect(x: 22, y: 22, width: 212, height: 212))
        context.setStrokeColor(UIColor.systemYellow.cgColor)
        context.setLineWidth(12)
        context.setLineDash(phase: 0, lengths: [18, 12])
        context.strokeEllipse(in: CGRect(x: 30, y: 30, width: 196, height: 196))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}

enum PencilRotationIndicatorFactory {
    static func make(radius: Float) -> Entity {
        makeIndicator(
            named: "pencil_rotation_indicator",
            radius: radius,
            textureImage: makeTexture()
        )
    }

    private static func makeTexture() -> CGImage? {
        let size = CGSize(width: 256, height: 256)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.28).cgColor)
        context.setLineWidth(24)
        context.strokeEllipse(in: CGRect(x: 22, y: 22, width: 212, height: 212))
        context.setStrokeColor(UIColor.systemYellow.cgColor)
        context.setLineWidth(13)
        context.setLineCap(.round)
        context.addArc(
            center: CGPoint(x: 128, y: 128),
            radius: 96,
            startAngle: -.pi * 0.82,
            endAngle: .pi * 0.42,
            clockwise: false
        )
        context.strokePath()
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 117, y: 18, width: 22, height: 22))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}

private func makeIndicator(named name: String, radius: Float, textureImage: CGImage?) -> Entity {
    let indicator = Entity()
    indicator.name = name
    guard let textureImage,
          let texture = try? TextureResource(image: textureImage, options: .init(semantic: .color)) else {
        return indicator
    }

    var material = UnlitMaterial()
    material.color = .init(tint: .white, texture: .init(texture))
    material.blending = .transparent(opacity: .init(floatLiteral: 0.95))
    let size = radius * 2
    let model = ModelEntity(
        mesh: .generatePlane(width: size, depth: size),
        materials: [material]
    )
    model.position = [0, 0.006, 0]
    indicator.addChild(model)
    return indicator
}
