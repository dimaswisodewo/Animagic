import SwiftUI

struct BackpackPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router
    @Environment(DrawingSessionManager.self) private var drawingSession
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore

    @State private var selectedCategory: ArtworkCategory?
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private var filteredDrawings: [SavedDrawing] {
        ArtworkFilter.filter(
            artworkStore.savedDrawings,
            searchText: searchText,
            category: selectedCategory
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            BackpackHeader(
                searchText: $searchText,
                onBack: dismiss.callAsFunction,
                onDrawMore: startNewDrawing,
                onOpenAR: openAR
            )
            BackpackCategoryBar(selectedCategory: $selectedCategory)
            drawingContent
        }
        .background(AnimagicTheme.yellow)
        .navigationBarHidden(true)
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
        router.push(.arView(initialCutoutID: nil))
    }

    private static let scrollSpace = "backpack-scroll"
    private static let gridColumns = [
        GridItem(.adaptive(minimum: 200))
    ]
}

#if DEBUG
#Preview {
    BackpackPageView()
        .environment(NavigationRouter())
        .environment(DrawingSessionManager())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
#endif
