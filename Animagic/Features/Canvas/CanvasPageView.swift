//
//  CanvasPageView.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 22/07/26.
//

import PencilKit
import SwiftUI

enum CanvasCompletionBehavior {
    case returnToPresentingAR
    case openNewAR

    @MainActor
    func complete(
        cutoutID: UUID,
        router: NavigationRouter,
        drawingSession: DrawingSessionManager
    ) {
        switch self {
        case .returnToPresentingAR:
            drawingSession.publishARCutout(cutoutID)
            router.dismissFullScreenCover()
        case .openNewAR:
            router.push(.arView(initialCutoutID: cutoutID))
        }
    }
}

struct CanvasPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NavigationRouter.self) private var router
    @Environment(DrawingSessionManager.self) private var drawingSession
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    @State private var documentTitle = ""
    @State private var canvasView = PKCanvasView()
    @State private var selectedGuideAnimal: GuideAnimal?
    @State private var isGuidePresented = false
    @State private var isClassifyingDoodle = false
    @State private var hasDrawing = false
    @State private var showEmptyCanvasMessage = false
    @State private var isDocumentTitleManuallyEdited = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var classificationCoordinator = DoodleClassificationCoordinator()
    @State private var classificationError: String?
    @State private var failedCutoutID: UUID?
    private let completionBehavior: CanvasCompletionBehavior

    init(completionBehavior: CanvasCompletionBehavior = .openNewAR) {
        self.completionBehavior = completionBehavior
    }

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
            .animation(guideAnimation, value: isGuidePresented)
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .alert("Your canvas is empty", isPresented: $showEmptyCanvasMessage) {
                Button("Keep Drawing", role: .cancel) {}
            } message: {
                Text("Draw something first, then let’s bring it to life!")
            }
            .alert(
                "AniMagic Couldn’t Recognize This Doodle",
                isPresented: classificationErrorIsPresented
            ) {
                Button("Retry AI") {
                    saveAndClassify()
                }
                Button("Use Generic in AR") {
                    openGenericAR()
                }
                Button("Stay on Canvas", role: .cancel) {}
            } message: {
                Text(classificationError ?? "The drawing was saved, but AI classification failed.")
            }
            .onAppear(perform: loadDrawing)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .inactive || phase == .background else { return }
                flushDraft()
            }
            .onDisappear {
                flushDraft()
                classificationCoordinator.cancel()
                isClassifyingDoodle = false
            }
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
                isDocumentTitleManuallyEdited: $isDocumentTitleManuallyEdited,
                onSave: saveAndClassify,
                onTitleChanged: scheduleDraftAutosave
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
                onDrawingChanged: { hasDrawing = $0; drawingDidChange() }
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
            .transition(guideTransition)
            .zIndex(1)
        }
    }

    private var guideAnimation: Animation {
        if reduceMotion {
            return AnimagicMotion.reduced
        }
        return isGuidePresented ? AnimagicMotion.panelEntrance : AnimagicMotion.panelExit
    }

    private var guideTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .trailing).combined(with: .opacity)
    }

    private func loadDrawing() {
        if let activeDrawing = artworkStore.drawing(id: drawingSession.activeDrawingID) {
            canvasView.drawing = activeDrawing.drawing
            documentTitle = activeDrawing.name
            isDocumentTitleManuallyEdited = activeDrawing.isNameManuallyEdited
        } else {
            canvasView.drawing = drawingSession.drawing.strokes.isEmpty
                ? PKDrawing()
                : drawingSession.drawing
        }
        hasDrawing = !canvasView.drawing.strokes.isEmpty
        if let activeDrawingID = drawingSession.activeDrawingID,
           let cutout = artworkStore.cutout(forDrawingID: activeDrawingID),
           let error = cutout.doodleClassificationError {
            failedCutoutID = cutout.id
            classificationError = error
        }
    }

    private var classificationErrorIsPresented: Binding<Bool> {
        Binding(
            get: { classificationError != nil && !isClassifyingDoodle },
            set: { isPresented in
                if !isPresented {
                    classificationError = nil
                }
            }
        )
    }

    private func drawingDidChange() {
        drawingSession.drawing = canvasView.drawing
        scheduleDraftAutosave()
    }

    private func scheduleDraftAutosave() {
        autosaveTask?.cancel()
        guard hasDrawing else { return }
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            saveDraft()
        }
    }

    private func flushDraft() {
        autosaveTask?.cancel()
        autosaveTask = nil
        saveDraft()
    }

    private func saveDraft() {
        let drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty, !drawing.bounds.isEmpty else { return }
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        artworkStore.saveActiveDrawing(
            id: drawingSession.activeDrawingID,
            name: title,
            drawing: drawing,
            isNameManuallyEdited: isDocumentTitleManuallyEdited && !title.isEmpty
        ) { savedDrawing in
            drawingSession.activeDrawingID = savedDrawing.id
            drawingSession.drawing = drawing
        }
    }

    private func saveAndClassify() {
        guard !isClassifyingDoodle else { return }
        let drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty, !drawing.bounds.isEmpty else {
            showEmptyCanvasMessage = true
            return
        }

        autosaveTask?.cancel()
        classificationError = nil
        failedCutoutID = nil
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        artworkStore.saveActiveDrawing(
            id: drawingSession.activeDrawingID,
            name: title,
            drawing: drawing,
            isNameManuallyEdited: isDocumentTitleManuallyEdited && !title.isEmpty
        ) { savedDrawing in
            drawingSession.activeDrawingID = savedDrawing.id
            drawingSession.drawing = drawing
            startClassification(drawing: drawing, sourceDrawingID: savedDrawing.id)
        }
    }

    private func startClassification(drawing: PKDrawing, sourceDrawingID: UUID) {
        isClassifyingDoodle = true
        classificationCoordinator.start(
            drawing: drawing,
            sourceDrawingID: sourceDrawingID,
            renderScale: displayScale
        ) { cutout in
            artworkStore.persistClassifiedCutout(
                cutout,
                forDrawingID: sourceDrawingID,
                replacingExistingCutouts: true,
                onFailure: {
                    isClassifyingDoodle = false
                }
            ) { updatedDrawing in
                documentTitle = updatedDrawing.name
                isDocumentTitleManuallyEdited = updatedDrawing.isNameManuallyEdited
                isClassifyingDoodle = false
                if let error = cutout.doodleClassificationError {
                    failedCutoutID = cutout.id
                    classificationError = error
                } else {
                    complete(with: cutout.id)
                }
            }
        }
    }

    private func openGenericAR() {
        guard let failedCutoutID else { return }
        classificationError = nil
        complete(with: failedCutoutID)
    }

    private func complete(with cutoutID: UUID) {
        completionBehavior.complete(
            cutoutID: cutoutID,
            router: router,
            drawingSession: drawingSession
        )
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
                Text("AniMagix is recognizing your doodle…")
                    .font(.custom("Belanosima-SemiBold", size: 28))
                    .foregroundStyle(Color(Color.Palette.n70))
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

#if DEBUG
#Preview {
    CanvasPageView()
        .environment(NavigationRouter())
        .environment(DrawingSessionManager())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
#endif
