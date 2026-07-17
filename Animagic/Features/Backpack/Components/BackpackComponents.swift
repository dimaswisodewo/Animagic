import PencilKit
import SwiftUI

enum ArtworkFilter {
    static func filter(
        _ drawings: [SavedDrawing],
        searchText: String,
        category: ArtworkCategory?
    ) -> [SavedDrawing] {
        drawings.filter { drawing in
            let matchesSearch = searchText.isEmpty
                || drawing.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = category == nil || drawing.category == category
            return matchesSearch && matchesCategory
        }
    }
}

struct BackpackHeader: View {
    let onBack: () -> Void
    let onDrawMore: () -> Void
    let onOpenAR: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                TopBarIconButton(icon: "chevron.left", action: onBack)
                Text("My Backpack")
                    .font(.custom("Belanosima-SemiBold", size: 32, relativeTo: .title))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(.black)
            }
            Spacer()
            TopBarButton(title: "Draw More!", action: onDrawMore)
            BackpackARButton(action: onOpenAR)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

struct BackpackFilterBar: View {
    @Binding var selectedCategory: ArtworkCategory?
    @Binding var searchText: String
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let categories: [ArtworkCategory?] = [nil, .skies, .underwater, .land]

    var body: some View {
        Group {
            if sizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    /// Single-row layout for regular (wide) size classes.
    private var regularLayout: some View {
        HStack(spacing: 16) {
            tabButtons
            Spacer()
            searchField
        }
    }

    /// Stacked layout for compact (narrow) size classes — scrollable tabs above search.
    private var compactLayout: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    tabButtons
                }
            }
            searchField
        }
    }

    @ViewBuilder
    private var tabButtons: some View {
        ForEach(categories, id: \.self) { category in
            BackpackTabButton(
                title: category?.title ?? "All",
                isSelected: selectedCategory == category
            ) {
                selectedCategory = category
            }
        }
    }

    private var searchField: some View {
        HStack {
            TextField("Search.....", text: $searchText)
                .font(.custom("Belanosima-Regular", size: 18, relativeTo: .body))
                .foregroundStyle(.black)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.black, lineWidth: 3))
        .frame(minWidth: 120, maxWidth: 300)
    }
}

struct BackpackDrawingCard: View {
    let drawing: SavedDrawing
    let classificationError: String?

    var body: some View {
        VStack(spacing: 0) {
            if drawing.drawing.bounds.isEmpty {
                Spacer()
                Text("Empty Drawing")
                    .font(.custom("Belanosima-Regular", size: 16, relativeTo: .subheadline))
                    .foregroundStyle(.gray)
                Spacer()
            } else {
                Image(uiImage: drawing.drawing.image(from: drawing.drawing.bounds, scale: 1))
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            }
            Text(drawing.name.isEmpty ? "Untitled" : drawing.name)
                .font(.custom("Belanosima-Bold", size: 20, relativeTo: .headline))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.black)
                .padding(.bottom, 12)
            if classificationError != nil {
                Label("AI retry available", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black, lineWidth: 3))
    }
}

struct BackpackScrollIndicator: View {
    let scrollOffset: CGFloat
    let contentHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let visibleRatio = geometry.size.height / max(1, contentHeight)
            let scrollableHeight = max(1, contentHeight - geometry.size.height)
            let progress = max(0, min(1, -scrollOffset / scrollableHeight))
            let indicatorHeight = max(40, geometry.size.height * visibleRatio)
            let availableTravel = geometry.size.height - indicatorHeight

            if visibleRatio < 1 {
                Capsule()
                    .fill(.black)
                    .frame(width: 8, height: indicatorHeight)
                    .offset(y: progress * availableTravel)
                    .padding(.trailing, 8)
            }
        }
        .frame(width: 16)
    }
}

private struct BackpackARButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "camera")
                Image(systemName: "sparkles")
            }
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AnimagicTheme.orange)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black, lineWidth: 3))
        }
        .buttonStyle(.animagicPress)
    }
}

private struct BackpackTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Belanosima-Bold", size: 20, relativeTo: .headline))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(isSelected ? AnimagicTheme.blue : AnimagicTheme.pink)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? .white : .black, lineWidth: 3))
        }
        .buttonStyle(.animagicPress)
    }
}
