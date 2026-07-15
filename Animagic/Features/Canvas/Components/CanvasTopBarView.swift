import SwiftUI
import PencilKit

struct CanvasTopBarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router
    @Environment(DrawingSessionManager.self) private var drawingSession
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @Binding var documentTitle: String
    let canvasView: PKCanvasView
    @Binding var showGuidePopup: Bool
    @Binding var isClassifyingDoodle: Bool
    @Binding var hasDrawing: Bool
    @Binding var showEmptyCanvasMessage: Bool
    @Binding var isDocumentTitleManuallyEdited: Bool
    
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
                saveDrawing()
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
            }
        )
    }

    private func saveDrawing() {
        guard !isClassifyingDoodle else { return }
        let drawing = canvasView.drawing
        guard hasDrawing, !drawing.strokes.isEmpty, !drawing.bounds.isEmpty else {
            showEmptyCanvasMessage = true
            return
        }

        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        artworkStore.saveActiveDrawing(
            id: drawingSession.activeDrawingID,
            name: title,
            drawing: drawing,
            isNameManuallyEdited: isDocumentTitleManuallyEdited && !title.isEmpty
        ) { savedDrawing in
            classify(drawing, for: savedDrawing)
        }
    }

    private func classify(_ drawing: PKDrawing, for savedDrawing: SavedDrawing) {
        let bounds = drawing.bounds
        let image = drawing.image(from: bounds, scale: 1)
        drawingSession.activeDrawingID = savedDrawing.id
        drawingSession.drawing = drawing
        isClassifyingDoodle = true

        Task.detached(priority: .userInitiated) {
            let startedAt = DispatchTime.now().uptimeNanoseconds
            let cutout = ClassifiedCutoutFactory().makeCutout(
                from: image,
                originalSize: bounds.size,
                sourceDrawingID: savedDrawing.id
            )
            let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
            let minimumDuration: UInt64 = 1_200_000_000
            if elapsed < minimumDuration {
                try? await Task.sleep(nanoseconds: minimumDuration - elapsed)
            }

            await MainActor.run {
                persist(cutout, for: savedDrawing.id)
            }
        }
    }

    private func persist(_ cutout: CutoutAsset, for drawingID: UUID) {
        artworkStore.persistClassifiedCutout(
            cutout,
            forDrawingID: drawingID,
            replacingExistingCutouts: true,
            onFailure: { isClassifyingDoodle = false }
        ) { updatedDrawing in
            documentTitle = updatedDrawing.name
            isDocumentTitleManuallyEdited = updatedDrawing.isNameManuallyEdited
            isClassifyingDoodle = false
            router.push(.arView(initialCutoutID: artworkStore.cutoutLibrary.last?.id))
        }
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
                .font(.custom("Belanosima-SemiBold", size: 20))
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
