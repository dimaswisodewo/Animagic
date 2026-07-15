import SwiftUI

struct BackpackPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
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
                onBack: dismiss.callAsFunction,
                onDrawMore: startNewDrawing,
                onOpenAR: openAR
            )
            BackpackFilterBar(
                selectedCategory: $selectedCategory,
                searchText: $searchText
            )
            drawingContent
        }
        .background(AnimagicTheme.yellow)
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private var drawingContent: some View {
        if filteredDrawings.isEmpty {
            ContentUnavailableView(
                "No Drawings Found",
                systemImage: "paintpalette",
                description: Text("Try another filter or draw a new animal.")
            )
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

    private var drawingGrid: some View {
        ScrollView {
            LazyVGrid(columns: Self.gridColumns, spacing: 20) {
                ForEach(filteredDrawings) { drawing in
                    Button {
                        appState.navigationPath.append(NavigationRoute.handdrawnDetail(drawing.id))
                    } label: {
                        BackpackDrawingCard(drawing: drawing)
                    }
                    .buttonStyle(.plain)
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
        appState.startNewDrawing()
        appState.navigationPath.append(NavigationRoute.canvas)
    }

    private func openAR() {
        appState.navigationPath.append(NavigationRoute.arView)
    }

    private static let scrollSpace = "backpack-scroll"
    private static let gridColumns = Array(
        repeating: GridItem(.flexible()),
        count: 3
    )
}

#Preview {
    BackpackPageView()
        .environmentObject(AppState())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
