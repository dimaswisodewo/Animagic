import PencilKit
import SwiftUI

struct DrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isToolPickerVisible = true
    var isHoverModeEnabled = false
    var onDrawingChanged: (Bool) -> Void = { _ in }
    var onSqueeze: ((CGPoint) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged, onSqueeze: onSqueeze)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        configure(canvasView, coordinator: context.coordinator)
        context.coordinator.attachToolPicker(to: canvasView, isVisible: isToolPickerVisible)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.isHoverModeEnabled = isHoverModeEnabled
        context.coordinator.onDrawingChanged = onDrawingChanged
        context.coordinator.setToolPickerVisibility(
            isToolPickerVisible,
            for: canvasView
        )
    }

    static func dismantleUIView(_ canvasView: PKCanvasView, coordinator: Coordinator) {
        coordinator.detachToolPicker(from: canvasView)
        canvasView.delegate = nil
    }

    private func configure(_ canvasView: PKCanvasView, coordinator: Coordinator) {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.delegate = coordinator
        
        let interaction = UIPencilInteraction()
        interaction.delegate = coordinator
        canvasView.addInteraction(interaction)
        
        let hover = UIHoverGestureRecognizer(target: coordinator, action: #selector(coordinator.hover(_:)))
        canvasView.addGestureRecognizer(hover)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var onDrawingChanged: (Bool) -> Void
        var onSqueeze: ((CGPoint) -> Void)?
        var isHoverModeEnabled = false
        
        private let toolPicker = PKToolPicker()
        private var lastHoverLocation: CGPoint?
        private var hoverPreviewLayer: CAShapeLayer?
        
        // Hover mode drawing state
        private var currentHoverPoints: [PKStrokePoint] = []
        private var hoverStrokeStartTime: Date?
        private var baselineDrawing: PKDrawing?

        init(onDrawingChanged: @escaping (Bool) -> Void, onSqueeze: ((CGPoint) -> Void)?) {
            self.onDrawingChanged = onDrawingChanged
            self.onSqueeze = onSqueeze
        }

        func attachToolPicker(to canvasView: PKCanvasView, isVisible: Bool) {
            toolPicker.addObserver(canvasView)
            setToolPickerVisibility(isVisible, for: canvasView)
        }

        func detachToolPicker(from canvasView: PKCanvasView) {
            toolPicker.removeObserver(canvasView)
        }

        func setToolPickerVisibility(_ isVisible: Bool, for canvasView: PKCanvasView) {
            toolPicker.setVisible(isVisible, forFirstResponder: canvasView)
            if isVisible, !canvasView.isFirstResponder {
                canvasView.becomeFirstResponder()
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(!canvasView.drawing.strokes.isEmpty)
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            hoverPreviewLayer?.isHidden = true
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            hoverPreviewLayer?.isHidden = true
        }
        
        @objc func hover(_ recognizer: UIHoverGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view)
            lastHoverLocation = location
            
            guard let canvas = recognizer.view as? PKCanvasView else { return }
            
            if !isHoverModeEnabled {
                updateHoverPreview(in: canvas, location: location, state: recognizer.state)
                return
            }
            
            // Hide preview if we switched to hover mode
            hoverPreviewLayer?.isHidden = true
            
            let color = (canvas.tool as? PKInkingTool)?.color ?? .black
            let width = (canvas.tool as? PKInkingTool)?.width ?? 5.0
            let inkType = (canvas.tool as? PKInkingTool)?.inkType ?? .pen
            let ink = PKInk(inkType, color: color)
            
            switch recognizer.state {
            case .began:
                hoverStrokeStartTime = Date()
                let point = PKStrokePoint(location: location, timeOffset: 0, size: CGSize(width: width, height: width), opacity: 1, force: 1, azimuth: 0, altitude: .pi/2)
                currentHoverPoints = [point]
                baselineDrawing = canvas.drawing
                
            case .changed:
                guard let startTime = hoverStrokeStartTime, let baseline = baselineDrawing else { return }
                let timeOffset = Date().timeIntervalSince(startTime)
                let point = PKStrokePoint(location: location, timeOffset: timeOffset, size: CGSize(width: width, height: width), opacity: 1, force: 1, azimuth: 0, altitude: .pi/2)
                currentHoverPoints.append(point)
                
                let path = PKStrokePath(controlPoints: currentHoverPoints, creationDate: startTime)
                let stroke = PKStroke(ink: ink, path: path)
                var newDrawing = baseline
                newDrawing.strokes.append(stroke)
                canvas.drawing = newDrawing
                
            case .ended, .cancelled:
                guard let startTime = hoverStrokeStartTime, let baseline = baselineDrawing else { return }
                
                let path = PKStrokePath(controlPoints: currentHoverPoints, creationDate: startTime)
                let stroke = PKStroke(ink: ink, path: path)
                
                var finalDrawing = baseline
                finalDrawing.strokes.append(stroke)
                canvas.drawing = finalDrawing
                
                hoverStrokeStartTime = nil
                currentHoverPoints = []
                baselineDrawing = nil
                onDrawingChanged(!canvas.drawing.strokes.isEmpty)
                
            default:
                break
            }
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            if squeeze.phase == .ended {
                let location = lastHoverLocation ?? CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
                onSqueeze?(location)
            }
        }
        
        private func updateHoverPreview(in canvas: PKCanvasView, location: CGPoint, state: UIGestureRecognizer.State) {
            if hoverPreviewLayer == nil {
                let layer = CAShapeLayer()
                layer.fillColor = UIColor.clear.cgColor
                layer.strokeColor = UIColor.gray.withAlphaComponent(0.5).cgColor
                layer.lineWidth = 1.5
                canvas.layer.addSublayer(layer)
                hoverPreviewLayer = layer
            }
            
            guard let layer = hoverPreviewLayer else { return }
            
            if state == .ended || state == .cancelled {
                layer.isHidden = true
                return
            }
            
            let width = (canvas.tool as? PKInkingTool)?.width ?? 5.0
            // Make the preview slightly larger than the actual stroke width for visibility
            let displayWidth = max(width, 6.0) 
            
            layer.isHidden = false
            layer.fillColor = UIColor.clear.cgColor
            
            let path = UIBezierPath(ovalIn: CGRect(
                x: location.x - displayWidth/2,
                y: location.y - displayWidth/2,
                width: displayWidth,
                height: displayWidth
            ))
            
            // Disable implicit animation for instant tracking
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.path = path.cgPath
            CATransaction.commit()
        }
    }
}
