import PencilKit
import SwiftUI

struct CanvasPageView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore

    @State private var documentTitle = ""
    @State private var canvasView = PKCanvasView()
    @State private var selectedGuideAnimal: GuideAnimal?
    @State private var isGuidePresented = false
    @State private var isClassifyingDoodle = false
    @State private var hasDrawing = false
    @State private var showEmptyCanvasMessage = false
    @State private var isDocumentTitleManuallyEdited = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvasContent
                guidePanel(width: geometry.size.width * 0.45)
                if isClassifyingDoodle {
                    DoodleClassificationOverlay()
                        .zIndex(2)
                }
            }
            .animation(.easeInOut, value: isGuidePresented)
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .alert("Your canvas is empty", isPresented: $showEmptyCanvasMessage) {
                Button("Keep Drawing", role: .cancel) {}
            } message: {
                Text("Draw something first, then let’s bring it to life!")
            }
            .onAppear(perform: loadDrawing)
        }
    }

    private var canvasContent: some View {
        VStack(spacing: 0) {
            CanvasTopBarView(
                documentTitle: $documentTitle,
                canvasView: canvasView,
                showGuidePopup: $isGuidePresented,
                isClassifyingDoodle: $isClassifyingDoodle,
                hasDrawing: $hasDrawing,
                showEmptyCanvasMessage: $showEmptyCanvasMessage,
                isDocumentTitleManuallyEdited: $isDocumentTitleManuallyEdited
            )
            drawingArea
        }
    }

    private var drawingArea: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if let animal = selectedGuideAnimal {
                Image(systemName: animal.imageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray.opacity(0.15))
                    .padding(100)
            }
            DrawingView(
                canvasView: $canvasView,
                isToolPickerVisible: !isGuidePresented,
                onDrawingChanged: { hasDrawing = $0 }
            )
        }
    }

    @ViewBuilder
    private func guidePanel(width: CGFloat) -> some View {
        if isGuidePresented {
            HStack(spacing: 0) {
                Spacer()
                GuidePopupView(
                    isPresented: $isGuidePresented,
                    selectedAnimal: $selectedGuideAnimal
                )
                .frame(width: width)
                .shadow(radius: 10)
            }
            .transition(.move(edge: .trailing))
            .zIndex(1)
        }
    }

    private func loadDrawing() {
        if let activeDrawing = artworkStore.drawing(id: appState.activeDrawingID) {
            canvasView.drawing = activeDrawing.drawing
            documentTitle = activeDrawing.name
            isDocumentTitleManuallyEdited = activeDrawing.isNameManuallyEdited
        } else {
            canvasView.drawing = appState.drawing.strokes.isEmpty
                ? PKDrawing()
                : appState.drawing
        }
        hasDrawing = !canvasView.drawing.strokes.isEmpty
    }
}

private struct DoodleClassificationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.black)
                Text("AniMagic is recognizing your doodle…")
                    .font(.custom("Belanosima-SemiBold", size: 28))
                    .multilineTextAlignment(.center)
                Text("Preparing it for AR")
                    .font(.custom("Belanosima-Regular", size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(36)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AniMagic is recognizing your doodle")
    }
}

#Preview {
    CanvasPageView()
        .environmentObject(AppState())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
