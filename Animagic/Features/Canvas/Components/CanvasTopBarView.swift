import SwiftUI
import PencilKit

struct CanvasTopBarView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var documentTitle: String
    let canvasView: PKCanvasView
    @Binding var showGuidePopup: Bool
    @Binding var isClassifyingDoodle: Bool
    @Binding var hasDrawing: Bool
    @Binding var isDocumentTitleManuallyEdited: Bool
    let onSave: () -> Void
    let onTitleChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            AnimagicIconButton(icon: "chevron.left", backgroundColor: AnimagicTheme.orange) {
                dismiss()
            }
            
            AnimagicTextField(
                placeholder: "Name your drawing",
                text: editableTitle,
                icon: "pencil",
                iconPosition: .leading
            )
            .frame(maxWidth: 290)
            .accessibilityHint("Tap to name your drawing")
            
            Spacer()
            
            AnimagicLabelButton(title: "Guide", icon: "book.fill", backgroundColor: AnimagicTheme.orange) {
                withAnimation {
                    showGuidePopup = true
                }
            }
            
            AnimagicIconButton(icon: "arrow.uturn.backward", backgroundColor: AnimagicTheme.orange) {
                canvasView.undoManager?.undo()
            }
            
            AnimagicIconButton(icon: "arrow.uturn.forward", backgroundColor: AnimagicTheme.orange) {
                canvasView.undoManager?.redo()
            }
            
            AnimagicLabelButton(title: "Save", icon: "checkmark", backgroundColor: AnimagicTheme.orange, isDisabled: isClassifyingDoodle, isDimmed: !hasDrawing) {
                onSave()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AnimagicTheme.yellow)
    }

    private var editableTitle: Binding<String> {
        Binding(
            get: { documentTitle },
            set: {
                documentTitle = $0
                isDocumentTitleManuallyEdited = true
                onTitleChanged()
            }
        )
    }
}

