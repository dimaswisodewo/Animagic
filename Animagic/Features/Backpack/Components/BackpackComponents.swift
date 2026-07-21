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
    @Binding var searchText: String
    let onBack: () -> Void
    let onDrawMore: () -> Void
    let onOpenAR: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                AnimagicIconButton(icon: "chevron.left", backgroundColor: AnimagicTheme.orange, action: onBack)
                Text("My Backpack")
                    .font(.custom("Belanosima-SemiBold", size: 32, relativeTo: .title))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(.black)
            }
            Spacer()
            AnimagicTextField(placeholder: "Search.....", text: $searchText)
                .frame(minWidth: 120, maxWidth: 300)
            AnimagicIconButton(icon: "paintbrush.fill", backgroundColor: AnimagicTheme.orange, action: onDrawMore)
            AnimagicIconButton(icon: "camera.fill", backgroundColor: AnimagicTheme.orange, action: onOpenAR)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct BackpackCategoryBar: View {
    @Binding var selectedCategory: ArtworkCategory?
    private let categories: [ArtworkCategory?] = [nil, .underwater, .land, .skies]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    let title = category?.title ?? "All"
                    
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(title)
                            .font(.custom("Belanosima-SemiBold", size: 28))
                            .foregroundStyle(isSelected ? .white : AnimagicTheme.blue)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(isSelected ? AnimagicTheme.blue : AnimagicTheme.blue.opacity(0.15))
                            )
                            .padding(6)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}


struct BackpackDrawingCard: View {
    let drawing: SavedDrawing
    let classificationError: String?

    var body: some View {
        VStack(spacing: 8) {
            AnimagicCard(title: drawing.name.isEmpty ? "Untitled" : drawing.name) {
                if drawing.drawing.bounds.isEmpty {
                    Text("Empty Drawing")
                        .font(.custom("Belanosima-Regular", size: 16, relativeTo: .subheadline))
                        .foregroundStyle(.gray)
                } else {
                    Image(uiImage: drawing.drawing.image(from: drawing.drawing.bounds, scale: 1))
                        .resizable()
                        .scaledToFit()
                }
            }
            if classificationError != nil {
                Label("AI retry available", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
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


