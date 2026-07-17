import PencilKit
import SwiftUI

struct HanddrawnDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore

    let drawingID: UUID

    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showSaveSuccess = false
    @State private var photoLibrarySaver: PhotoLibrarySaver?

    private var drawing: SavedDrawing {
        artworkStore.drawing(id: drawingID)
            ?? SavedDrawing(id: drawingID, name: "", drawing: PKDrawing())
    }

    var body: some View {
        VStack(spacing: 0) {
            HanddrawnDetailHeader(
                title: drawing.name.isEmpty ? "Untitled" : drawing.name,
                onBack: dismiss.callAsFunction,
                onOpenAR: classifyAndOpenAR,
                onShare: { showShareSheet = true },
                onSave: saveToGallery,
                onDelete: { showDeleteConfirmation = true }
            )
            HanddrawnArtworkView(drawing: drawing.drawing)
        }
        .navigationBarHidden(true)
        .alert("Delete Drawing", isPresented: $showDeleteConfirmation) {
            Button("Yes", role: .destructive, action: deleteDrawing)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(drawing.name.isEmpty ? "Untitled" : drawing.name)'?")
        }
        .alert("Saved Successfully", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [renderedImage ?? UIImage()])
        }
    }

    private var renderedImage: UIImage? {
        guard !drawing.drawing.bounds.isEmpty else { return nil }
        return drawing.drawing.image(from: drawing.drawing.bounds, scale: 1)
    }

    private func classifyAndOpenAR() {
        guard let image = renderedImage else { return }
        let drawing = drawing

        Task.detached(priority: .userInitiated) {
            let cutout = ClassifiedCutoutFactory().makeCutout(
                from: image,
                originalSize: image.size,
                sourceDrawingID: drawing.id
            )
            await MainActor.run {
                artworkStore.persistClassifiedCutout(
                    cutout,
                    forDrawingID: drawing.id,
                    replacingExistingCutouts: false
                ) { _ in
                    router.push(.arView(initialCutoutID: artworkStore.cutoutLibrary.last?.id))
                }
            }
        }
    }

    private func saveToGallery() {
        guard let image = renderedImage else { return }
        let saver = PhotoLibrarySaver {
            showSaveSuccess = true
            photoLibrarySaver = nil
        }
        photoLibrarySaver = saver
        saver.save(image)
    }

    private func deleteDrawing() {
        artworkStore.deleteDrawing(id: drawing.id) {
            dismiss()
        }
    }
}

#if DEBUG
#Preview {
    HanddrawnDetailView(drawingID: UUID())
        .environment(NavigationRouter())
        .environment(DrawingSessionManager())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
#endif
