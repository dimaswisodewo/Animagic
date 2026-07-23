import PencilKit
import SwiftUI

struct HanddrawnDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @Environment(\.displayScale) private var displayScale

    let drawingID: UUID

    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showSaveSuccess = false
    @State private var photoLibrarySaver: PhotoLibrarySaver?
    @State private var classificationCoordinator = DoodleClassificationCoordinator()
    @State private var classificationError: String?
    @State private var failedCutoutID: UUID?
    @State private var titleDraft = ""

    private var drawing: SavedDrawing {
        artworkStore.drawing(id: drawingID)
            ?? SavedDrawing(id: drawingID, name: "", drawing: PKDrawing())
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HanddrawnDetailHeader(
                    title: $titleDraft,
                    onTitleCommit: { commitTitleChange() },
                    onBack: { commitTitleChange(onSuccess: dismiss.callAsFunction) },
                    onOpenAR: classifyAndOpenAR,
                    onShare: { showShareSheet = true },
                    onSave: saveToGallery,
                    onDelete: { showDeleteConfirmation = true }
                )
                if let classificationError, !classificationCoordinator.isRunning {
                    classificationRecoveryBanner(message: classificationError)
                }
                HanddrawnArtworkView(drawing: drawing.drawing)
            }

            if classificationCoordinator.isRunning {
                detailClassificationOverlay
                    .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .alert("Delete Drawing", isPresented: $showDeleteConfirmation) {
            Button("Yes", role: .destructive, action: deleteDrawing)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also removes its cutout from AR. Delete '\(ArtworkLibraryPresentation.displayName(for: drawing))'?")
        }
        .alert("Saved Successfully", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [renderedImage ?? UIImage()])
        }
        .onAppear {
            synchronizeTitleDraft()
            loadClassificationRecovery()
        }
        .onChange(of: drawing.name) {
            synchronizeTitleDraft()
        }
        .onDisappear {
            classificationCoordinator.cancel()
        }
    }

    private var renderedImage: UIImage? {
        guard !drawing.drawing.bounds.isEmpty else { return nil }
        return drawing.drawing.image(
            from: drawing.drawing.bounds,
            scale: displayScale
        )
    }

    private func synchronizeTitleDraft() {
        titleDraft = ArtworkLibraryPresentation.displayName(for: drawing)
    }

    private func commitTitleChange(onSuccess: @escaping @MainActor () -> Void = {}) {
        let normalizedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedTitle = ArtworkLibraryPresentation.displayName(for: drawing)

        guard !normalizedTitle.isEmpty else {
            titleDraft = savedTitle
            onSuccess()
            return
        }
        guard normalizedTitle != drawing.name else {
            titleDraft = savedTitle
            onSuccess()
            return
        }

        artworkStore.renameDrawing(
            id: drawing.id,
            to: normalizedTitle,
            onFailure: { titleDraft = savedTitle },
            onSuccess: { updatedDrawing in
                titleDraft = updatedDrawing.name
                onSuccess()
            }
        )
    }

    private func classifyAndOpenAR() {
        guard !classificationCoordinator.isRunning,
              !drawing.drawing.strokes.isEmpty,
              !drawing.drawing.bounds.isEmpty else { return }

        classificationError = nil
        failedCutoutID = nil
        classificationCoordinator.start(
            drawing: drawing.drawing,
            sourceDrawingID: drawing.id,
            renderScale: displayScale
        ) { cutout in
            artworkStore.persistClassifiedCutout(
                cutout,
                forDrawingID: drawing.id,
                replacingExistingCutouts: true
            ) { _ in
                if let error = cutout.doodleClassificationError {
                    failedCutoutID = cutout.id
                    classificationError = error
                } else {
                    router.push(.arView(initialCutoutID: cutout.id))
                }
            }
        }
    }

    private func loadClassificationRecovery() {
        guard let cutout = artworkStore.cutout(forDrawingID: drawingID),
              let error = cutout.doodleClassificationError else { return }
        failedCutoutID = cutout.id
        classificationError = error
    }

    private func retryClassification() {
        classifyAndOpenAR()
    }

    private func openGenericAR() {
        guard let failedCutoutID else { return }
        classificationError = nil
        router.push(.arView(initialCutoutID: failedCutoutID))
    }

    private func classificationRecoveryBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI classification needs another try", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Retry AI", action: retryClassification)
                    .buttonStyle(.borderedProminent)
                Button("Use Generic in AR", action: openGenericAR)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
    }

    private var detailClassificationOverlay: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("AniMagix is recognizing your doodle…")
                    .font(.custom("Belanosima-SemiBold", size: 28))
                    .foregroundStyle(Color(Color.Palette.n70))
                    .multilineTextAlignment(.center)
                Text("Preparing it for AR")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AniMagic is recognizing your doodle")
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
