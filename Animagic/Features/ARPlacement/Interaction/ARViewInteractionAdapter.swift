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
    private let pencilMovementMechanic: PencilMovementMechanic
    private let onEmptyTap: (CGPoint) -> Void
    private let onPencilAreaTapped: (SurfaceProjection) -> Void
    private var recognizers: [UIGestureRecognizer] = []
    private var session: GestureSession = .idle
    private var activeTransformGestures: Set<TransformGesture> = []
    private var isPencilInteractionEnabled = false

    init(
        manager: any ObjectInteractionManaging,
        surfaceProjector: any SurfaceProjecting,
        pencilMovementMechanic: PencilMovementMechanic,
        onEmptyTap: @escaping (CGPoint) -> Void,
        onPencilAreaTapped: @escaping (SurfaceProjection) -> Void
    ) {
        self.manager = manager
        self.surfaceProjector = surfaceProjector
        self.pencilMovementMechanic = pencilMovementMechanic
        self.onEmptyTap = onEmptyTap
        self.onPencilAreaTapped = onPencilAreaTapped
    }

    func attach(to arView: ARView) {
        detach()
        self.arView = arView

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        let pencilTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handlePencilTap(_:))
        )
        let pencilPan = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePencilPan(_:))
        )

        tap.numberOfTouchesRequired = 1
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        let directTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        tap.allowedTouchTypes = directTouchTypes
        pan.allowedTouchTypes = directTouchTypes
        pinch.allowedTouchTypes = directTouchTypes
        rotation.allowedTouchTypes = directTouchTypes
        let pencilTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        pencilTap.allowedTouchTypes = pencilTouchTypes
        pencilPan.allowedTouchTypes = pencilTouchTypes
        tap.require(toFail: pan)
        pencilTap.require(toFail: pencilPan)

        [tap, pan, pinch, rotation, pencilTap, pencilPan].forEach {
            $0.delegate = self
            arView.addGestureRecognizer($0)
        }
        recognizers = [tap, pan, pinch, rotation, pencilTap, pencilPan]
    }

    func setPencilInteractionEnabled(_ isEnabled: Bool) {
        isPencilInteractionEnabled = isEnabled
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
        guard !isPencilOnlyInteractionActive, let arView else {
            return
        }
        let point = recognizer.location(in: arView)
        let entity = hitEntity(at: point, in: arView)
        if !manager.handleTap(on: entity) {
            onEmptyTap(point)
        }
    }

    @objc private func handlePencilTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else {
            return
        }
        let point = recognizer.location(in: arView)
        let entity = hitEntity(at: point, in: arView)

        guard isPencilInteractionEnabled else {
            if !manager.handleTap(on: entity) {
                onEmptyTap(point)
            }
            return
        }

        switch pencilMovementMechanic {
        case .selectionFirst:
            if entity != nil {
                _ = manager.handleTap(on: entity)
            } else {
                moveSelection(to: point, in: arView)
            }
        case .directDragAndGather:
            guard let projection = surfaceProjector.project(point, in: arView) else {
                return
            }
            onPencilAreaTapped(projection)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard !isPencilOnlyInteractionActive else { return }
        handleDirectPan(recognizer)
    }

    @objc private func handlePencilPan(_ recognizer: UIPanGestureRecognizer) {
        guard isPencilInteractionEnabled else {
            handleDirectPan(recognizer)
            return
        }

        switch pencilMovementMechanic {
        case .selectionFirst:
            handleSelectionFirstPencilPan(recognizer)
        case .directDragAndGather:
            handlePrecisePencilPan(recognizer)
        }
    }

    private func handleDirectPan(_ recognizer: UIPanGestureRecognizer) {
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
            if let object = manager.selectedObject,
               let projection = surfaceProjector.project(point, in: arView, for: object) {
                manager.moveSelected(to: projection)
            }
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

    private func handleSelectionFirstPencilPan(_ recognizer: UIPanGestureRecognizer) {
        guard let arView else {
            return
        }
        let point = recognizer.location(in: arView)
        switch recognizer.state {
        case .began:
            guard case .idle = session else {
                cancel(recognizer)
                return
            }

            let hitEntity = hitEntity(at: point, in: arView)
            let didBeginDirectly = manager.beginTranslation(on: hitEntity)
            guard didBeginDirectly || manager.beginGuidedTranslation() else {
                cancel(recognizer)
                return
            }
            session = .translating
            updateTranslationTarget(to: point, in: arView)
        case .changed:
            guard case .translating = session else {
                return
            }
            updateTranslationTarget(to: point, in: arView)
        case .ended, .cancelled, .failed:
            if case .translating = session {
                manager.endTranslation()
                session = .idle
            }
        default:
            break
        }
    }

    private func handlePrecisePencilPan(_ recognizer: UIPanGestureRecognizer) {
        guard let arView else {
            return
        }
        let point = recognizer.location(in: arView)
        switch recognizer.state {
        case .began:
            let translation = recognizer.translation(in: arView)
            let initialPoint = CGPoint(
                x: point.x - translation.x,
                y: point.y - translation.y
            )
            guard case .idle = session,
                  manager.beginPreciseTranslation(
                    on: hitEntity(at: initialPoint, in: arView)
                  ) else {
                cancel(recognizer)
                return
            }
            session = .translating
            updatePreciseTranslation(to: point, in: arView)
        case .changed:
            guard case .translating = session else {
                return
            }
            updatePreciseTranslation(to: point, in: arView)
        case .ended, .cancelled, .failed:
            if case .translating = session {
                manager.endTranslation()
                manager.clearSelection()
                session = .idle
            }
        default:
            break
        }
    }

    private func moveSelection(to point: CGPoint, in arView: ARView) {
        guard let object = manager.selectedObject,
              let projection = surfaceProjector.project(point, in: arView, for: object),
              manager.beginGuidedTranslation() else {
            return
        }
        manager.moveSelected(to: projection)
        manager.endTranslation()
    }

    private func updateTranslationTarget(to point: CGPoint, in arView: ARView) {
        guard let object = manager.selectedObject,
              let projection = surfaceProjector.project(point, in: arView, for: object) else {
            return
        }
        manager.moveSelected(to: projection)
    }

    private func updatePreciseTranslation(to point: CGPoint, in arView: ARView) {
        guard let object = manager.selectedObject,
              let projection = surfaceProjector.project(point, in: arView, for: object) else {
            return
        }
        manager.moveSelectedPrecisely(to: projection)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard !isPencilOnlyInteractionActive, let arView else {
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
        guard !isPencilOnlyInteractionActive, let arView else {
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

    private var isPencilOnlyInteractionActive: Bool {
        guard isPencilInteractionEnabled else { return false }
        if case .directDragAndGather = pencilMovementMechanic {
            return true
        }
        return false
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
