import PencilKit
import SwiftUI

struct DrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isToolPickerVisible = true
    var onDrawingChanged: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        configure(canvasView, coordinator: context.coordinator)
        context.coordinator.attachToolPicker(to: canvasView, isVisible: isToolPickerVisible)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
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
        canvasView.drawingPolicy = .default
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.delegate = coordinator
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChanged: (Bool) -> Void
        private let toolPicker = PKToolPicker()

        init(onDrawingChanged: @escaping (Bool) -> Void) {
            self.onDrawingChanged = onDrawingChanged
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
    }
}
