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
            TopBarIconButton(icon: "chevron.left") {
                dismiss()
            }
            
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.65))
                TextField("Name your drawing", text: editableTitle)
                    .font(.custom("Belanosima-Regular", size: 22))
                    .foregroundColor(.black)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Drawing name")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.78), in: Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.3), lineWidth: 2))
            .frame(maxWidth: 290)
            .accessibilityHint("Tap to name your drawing")
            
            Spacer()
            
            TopBarButton(title: "Guide") {
                withAnimation {
                    showGuidePopup = true
                }
            }
            
            TopBarIconButton(icon: "arrow.uturn.backward") {
                canvasView.undoManager?.undo()
            }
            
            TopBarIconButton(icon: "arrow.uturn.forward") {
                canvasView.undoManager?.redo()
            }
            
            TopBarButton(title: "Save", isDisabled: isClassifyingDoodle, isDimmed: !hasDrawing) {
                onSave()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.Token.Background.primary)
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

struct TopBarButton: View {
    let title: String
    var isDisabled = false
    var isDimmed = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Belanosima-SemiBold", size: 20, relativeTo: .headline))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AnimagicTheme.orange)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.black, lineWidth: 3)
                )
        }
        .buttonStyle(.animagicPress)
        .opacity(isDimmed ? 0.55 : 1)
        .disabled(isDisabled)
    }
}

struct TopBarIconButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .padding(12)
                .background(AnimagicTheme.orange)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.black, lineWidth: 3)
                )
        }
        .buttonStyle(.animagicPress)
    }
}
