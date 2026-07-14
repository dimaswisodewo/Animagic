//
//  ARViewInteractionAdapter.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import RealityKit
import UIKit

@MainActor
final class ARViewInteractionAdapter: NSObject, UIGestureRecognizerDelegate {
    private enum GestureSession {
        case idle
        case translating
        case transforming
    }

    private enum TransformGesture: Hashable {
        case pinch
        case rotation
    }

    private weak var arView: ARView?
    private let manager: any ObjectInteractionManaging
    private let surfaceProjector: any SurfaceProjecting
    private let onEmptyTap: (CGPoint) -> Void
    private var recognizers: [UIGestureRecognizer] = []
    private var session: GestureSession = .idle
    private var activeTransformGestures: Set<TransformGesture> = []

    init(
        manager: any ObjectInteractionManaging,
        surfaceProjector: any SurfaceProjecting,
        onEmptyTap: @escaping (CGPoint) -> Void
    ) {
        self.manager = manager
        self.surfaceProjector = surfaceProjector
        self.onEmptyTap = onEmptyTap
    }

    func attach(to arView: ARView) {
        detach()
        self.arView = arView

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))

        tap.numberOfTouchesRequired = 1
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        tap.require(toFail: pan)

        [tap, pan, pinch, rotation].forEach {
            $0.delegate = self
            arView.addGestureRecognizer($0)
        }
        recognizers = [tap, pan, pinch, rotation]
    }

    func detach() {
        guard let arView else {
            recognizers.removeAll()
            session = .idle
            activeTransformGestures.removeAll()
            return
        }
        recognizers.forEach(arView.removeGestureRecognizer)
        recognizers.removeAll()
        self.arView = nil
        session = .idle
        activeTransformGestures.removeAll()
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else {
            return
        }
        let point = recognizer.location(in: arView)
        let entity = hitEntity(at: point, in: arView)
        if !manager.handleTap(on: entity) {
            onEmptyTap(point)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let arView else {
            return
        }
        let point = recognizer.location(in: arView)
        switch recognizer.state {
        case .began:
            guard case .idle = session,
                  manager.beginTranslation(on: hitEntity(at: point, in: arView)) else {
                cancel(recognizer)
                return
            }
            session = .translating
        case .changed:
            guard case .translating = session else {
                return
            }
            if let object = manager.selectedObject,
               let projection = surfaceProjector.project(point, in: arView, for: object) {
                manager.moveSelected(to: projection)
            }
        case .ended, .cancelled, .failed:
            if case .translating = session {
                manager.endTranslation()
                session = .idle
            }
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let arView else {
            return
        }
        switch recognizer.state {
        case .began:
            guard canBeginTransformSession,
                  manager.beginScale(
                    on: hitEntity(at: recognizer.location(in: arView), in: arView)
                  ) else {
                cancel(recognizer)
                return
            }
            session = .transforming
            activeTransformGestures.insert(.pinch)
        case .changed:
            guard case .transforming = session else {
                return
            }
            manager.scaleSelected(by: Float(recognizer.scale))
        case .ended, .cancelled, .failed:
            if case .transforming = session {
                manager.endScale()
                activeTransformGestures.remove(.pinch)
                finishTransformIfNeeded()
            }
        default:
            break
        }
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let arView else {
            return
        }
        switch recognizer.state {
        case .began:
            guard canBeginTransformSession,
                  manager.beginRotation(
                    on: hitEntity(at: recognizer.location(in: arView), in: arView)
                  ) else {
                cancel(recognizer)
                return
            }
            session = .transforming
            activeTransformGestures.insert(.rotation)
        case .changed:
            guard case .transforming = session else {
                return
            }
            manager.rotateSelected(by: Float(recognizer.rotation))
        case .ended, .cancelled, .failed:
            if case .transforming = session {
                manager.endRotation()
                activeTransformGestures.remove(.rotation)
                finishTransformIfNeeded()
            }
        default:
            break
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        (gestureRecognizer is UIPinchGestureRecognizer &&
            otherGestureRecognizer is UIRotationGestureRecognizer) ||
        (gestureRecognizer is UIRotationGestureRecognizer &&
            otherGestureRecognizer is UIPinchGestureRecognizer)
    }

    private var canBeginTransformSession: Bool {
        switch session {
        case .idle, .transforming:
            return true
        case .translating:
            return false
        }
    }

    private func cancel(_ recognizer: UIGestureRecognizer) {
        recognizer.isEnabled = false
        recognizer.isEnabled = true
    }

    private func finishTransformIfNeeded() {
        if activeTransformGestures.isEmpty {
            session = .idle
        }
    }

    private func hitEntity(at point: CGPoint, in arView: ARView) -> Entity? {
        arView.hitTest(point, query: .nearest, mask: .interactable).first?.entity
    }
}
