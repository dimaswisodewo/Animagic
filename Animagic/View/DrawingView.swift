import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isToolPickerVisible: Bool = true
    @State var toolPicker = PKToolPicker()

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput // Allows finger and Apple Pencil
        
        // Make canvas transparent so tracing image shows underneath
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        
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
}
