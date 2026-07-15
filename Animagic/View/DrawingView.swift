import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isToolPickerVisible: Bool = true
    var onDrawingChanged: (Bool) -> Void = { _ in }
    @State var toolPicker = PKToolPicker()

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        // Keep finger and palm touches from creating strokes while using Apple Pencil.
        canvasView.allowsFingerDrawing = false
        
        // Make canvas transparent so tracing image shows underneath
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.delegate = context.coordinator
        
        // Show tool picker
        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Toggle tool picker visibility dynamically
        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: uiView)
        if isToolPickerVisible && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let onDrawingChanged: (Bool) -> Void

        init(onDrawingChanged: @escaping (Bool) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(!canvasView.drawing.strokes.isEmpty)
        }
    }
}
