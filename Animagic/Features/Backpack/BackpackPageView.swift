//
//  BackpackPageView.swift
//  AniMagic
//
//  Created by dimaswisodewo on 23/07/26.
//

import Observation
import SwiftUI

struct BackpackPageView: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(NavigationRouter.self) private var router
    @Environment(DrawingSessionManager.self) private var drawingSession
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore

    @State private var selectedCategory: ArtworkCategory?
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var arSyncCoordinator = BackpackARSyncCoordinator()

    private var filteredDrawings: [SavedDrawing] {
        ArtworkFilter.filter(
            artworkStore.savedDrawings,
            searchText: searchText,
            category: selectedCategory
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                BackpackHeader(
                    searchText: $searchText,
                    onBack: router.pop,
                    onDrawMore: startNewDrawing,
                    onOpenAR: openAR
                )
                BackpackCategoryBar(selectedCategory: $selectedCategory)
                drawingContent
            }

            if arSyncCoordinator.isPreparing {
                BackpackARPreparationOverlay(
                    completedCount: arSyncCoordinator.completedCount,
                    totalCount: arSyncCoordinator.totalCount
                )
                .zIndex(1)
            }
        }
        .background(AnimagicTheme.yellow)
        .navigationBarHidden(true)
        .onDisappear {
            arSyncCoordinator.cancel()
        }
    }

    @ViewBuilder
    private var drawingContent: some View {
        if artworkStore.savedDrawings.isEmpty {
            emptyLibraryView
        } else if filteredDrawings.isEmpty {
            emptyResultsView
        } else {
            ZStack(alignment: .trailing) {
                drawingGrid
                BackpackScrollIndicator(
                    scrollOffset: scrollOffset,
                    contentHeight: contentHeight
                )
            }
        }
    }

    private var emptyLibraryView: some View {
        AnimagicEmptyState(
            icon: "backpack.fill",
            title: "Your Backpack Is Empty",
            message: "Draw your first doodle and it will appear here.",
            actionTitle: "Draw a Doodle",
            actionIcon: "paintbrush.fill",
            action: startNewDrawing
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResultsView: some View {
        AnimagicEmptyState(
            icon: "magnifyingglass",
            title: "No Drawings Found",
            message: "Try a different search or show every backpack category.",
            actionTitle: "Clear Filters",
            actionIcon: "arrow.counterclockwise",
            actionColor: AnimagicTheme.blue,
            action: clearFilters
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawingGrid: some View {
        ScrollView {
            LazyVGrid(columns: Self.gridColumns, spacing: 20) {
                ForEach(filteredDrawings) { drawing in
                    Button {
                        router.push(.handdrawnDetail(drawing.id))
                    } label: {
                        BackpackDrawingCard(
                            drawing: drawing,
                            classificationError: artworkStore.classificationError(forDrawingID: drawing.id)
                        )
                        .id(ArtworkLibraryPresentation.displayName(for: drawing))
                    }
                    .buttonStyle(.animagicPress)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(contentGeometryReader)
        }
        .coordinateSpace(name: Self.scrollSpace)
        .scrollIndicators(.hidden)
    }

    private var contentGeometryReader: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { updateScrollMetrics(from: geometry) }
                .onChange(of: geometry.frame(in: .named(Self.scrollSpace)).minY) {
                    updateScrollMetrics(from: geometry)
                }
                .onChange(of: geometry.size.height) {
                    updateScrollMetrics(from: geometry)
                }
        }
    }

    private func updateScrollMetrics(from geometry: GeometryProxy) {
        scrollOffset = geometry.frame(in: .named(Self.scrollSpace)).minY
        contentHeight = geometry.size.height
    }

    private func startNewDrawing() {
        drawingSession.startNewDrawing()
        router.push(.canvas)
    }

    private func clearFilters() {
        searchText = ""
        selectedCategory = nil
    }

    private func openAR() {
        arSyncCoordinator.prepareMissingCutouts(
            drawings: artworkStore.savedDrawings,
            cutouts: artworkStore.cutoutLibrary,
            renderScale: displayScale,
            artworkStore: artworkStore
        ) {
            router.push(.arView(initialCutoutID: nil))
        }
    }

    private static let scrollSpace = "backpack-scroll"
    private static let gridColumns = [
        GridItem(.adaptive(minimum: 200))
    ]
}

@MainActor
@Observable
private final class BackpackARSyncCoordinator {
    private(set) var completedCount = 0
    private(set) var totalCount = 0

    @ObservationIgnored
    private let classificationCoordinator = DoodleClassificationCoordinator()
    @ObservationIgnored
    private var pendingDrawings: [SavedDrawing] = []
    @ObservationIgnored
    private var renderScale: CGFloat = 1
    @ObservationIgnored
    private var artworkStore: ArtworkLibraryStore?
    @ObservationIgnored
    private var completion: (@MainActor () -> Void)?
    @ObservationIgnored
    private var generation = UUID()

    var isPreparing: Bool {
        totalCount > 0
    }

    func prepareMissingCutouts(
        drawings: [SavedDrawing],
        cutouts: [CutoutAsset],
        renderScale: CGFloat,
        artworkStore: ArtworkLibraryStore,
        completion: @escaping @MainActor () -> Void
    ) {
        guard !isPreparing else { return }

        let drawingIDsWithCutouts = Set(cutouts.compactMap(\.sourceDrawingID))
        let missingDrawings = drawings.filter { drawing in
            !drawing.drawing.strokes.isEmpty
                && !drawing.drawing.bounds.isEmpty
                && !drawingIDsWithCutouts.contains(drawing.id)
        }

        guard !missingDrawings.isEmpty else {
            completion()
            return
        }

        generation = UUID()
        completedCount = 0
        totalCount = missingDrawings.count
        pendingDrawings = missingDrawings
        self.renderScale = renderScale
        self.artworkStore = artworkStore
        self.completion = completion
        prepareNext(generation: generation)
    }

    func cancel() {
        generation = UUID()
        classificationCoordinator.cancel()
        reset()
    }

    private func prepareNext(generation currentGeneration: UUID) {
        guard generation == currentGeneration else { return }
        guard !pendingDrawings.isEmpty else {
            let completion = completion
            reset()
            completion?()
            return
        }

        let drawing = pendingDrawings.removeFirst()
        classificationCoordinator.start(
            drawing: drawing.drawing,
            sourceDrawingID: drawing.id,
            renderScale: renderScale
        ) { [weak self] cutout in
            guard let self,
                  self.generation == currentGeneration,
                  let artworkStore = self.artworkStore else { return }

            artworkStore.persistClassifiedCutout(
                cutout,
                forDrawingID: drawing.id,
                replacingExistingCutouts: false,
                onFailure: { [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    self.generation = UUID()
                    self.classificationCoordinator.cancel()
                    self.reset()
                }
            ) { [weak self] _ in
                guard let self, self.generation == currentGeneration else { return }
                self.completedCount += 1
                self.prepareNext(generation: currentGeneration)
            }
        }
    }

    private func reset() {
        completedCount = 0
        totalCount = 0
        pendingDrawings.removeAll()
        artworkStore = nil
        completion = nil
    }
}

private struct BackpackARPreparationOverlay: View {
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.black)

                Text("Preparing your doodles…")
                    .font(.custom("Belanosima-SemiBold", size: 28))
                    .foregroundStyle(Color.Palette.n70)
                    .multilineTextAlignment(.center)

                Text("\(completedCount) of \(totalCount) ready for AR")
                    .font(.custom("Belanosima-Regular", size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(36)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing doodles for augmented reality")
        .accessibilityValue("\(completedCount) of \(totalCount) complete")
    }
}

#if DEBUG
#Preview {
    BackpackPageView()
        .environment(NavigationRouter())
        .environment(DrawingSessionManager())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
#endif
