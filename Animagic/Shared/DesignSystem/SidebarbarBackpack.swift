//
//  SidebarbarBackpack.swift
//  AniMagic
//
//  Created by Gogo Figo on 21/07/26.
//
import SwiftUI

struct BackpackSidebar: View {
    let tabs: [String]
    let items: [String: [String]]
    let initialTab: String?
    let itemContent: ((String) -> AnyView)?
    let emptyContent: ((String) -> AnyView)?
    var onTabChanged: ((String) -> Void)? = nil
    var onItemTapped: ((String) -> Void)? = nil

    @State private var selectedTab: String

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        tabs: [String],
        items: [String: [String]],
        initialTab: String? = nil,
        onTabChanged: ((String) -> Void)? = nil,
        onItemTapped: ((String) -> Void)? = nil,
        emptyContent: ((String) -> AnyView)? = nil,
        itemContent: ((String) -> AnyView)? = nil
    ) {
        self.tabs = tabs
        self.items = items
        self.initialTab = initialTab
        self.itemContent = itemContent
        self.emptyContent = emptyContent
        self.onTabChanged = onTabChanged
        self.onItemTapped = onItemTapped
        _selectedTab = State(initialValue: initialTab ?? tabs.first ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            .padding(4)
            .background(Capsule().fill(Color.white))
            .overlay {
                Capsule()
                    .strokeBorder(Color(Color.Palette.b50), lineWidth: 3)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                shelfContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnimagicTheme.yellow, in: shelfShape)
        .clipShape(shelfShape)
        .overlay {
            shelfShape
                .strokeBorder(Color.white, lineWidth: 6)
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            onTabChanged?(tab)
        } label: {
            Text(tab)
                .font(.custom("Belanosima-SemiBold", size: 20, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(isSelected ? Color.white : AnimagicTheme.blue.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AnimagicTheme.blue : Color(Color.Palette.b50))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var shelfContent: some View {
        if let selectedItems = items[selectedTab], !selectedItems.isEmpty {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(selectedItems, id: \.self) { item in
                    itemButton(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else if let emptyContent {
            emptyContent(selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else {
            defaultEmptyContent
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    private func itemButton(_ item: String) -> some View {
        Button {
            onItemTapped?(item)
        } label: {
            if let itemContent {
                itemContent(item)
            } else {
                defaultItemContent
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item)
    }

    private var shelfShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: 24,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
    }

    private var defaultItemContent: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(Color.Palette.n10))
            .frame(width: 140, height: 128)
            .overlay {
                Image(systemName: "square")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.Palette.n70)
            }
    }

    private var defaultEmptyContent: some View {
        AnimagicEmptyState(
            icon: "backpack.fill",
            title: "Nothing Here Yet",
            message: "Add something to your backpack to see it here.",
            isCompact: true
        )
    }
}

struct BackpackTabButton: View {
    @Binding var isOpen: Bool

    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .white

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isOpen.toggle()
            }
        } label: {
            Group {
                if isOpen {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(iconColor)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(backgroundColor))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 6)
                            Circle()
                                .strokeBorder(innerBorderColor, lineWidth: 3)
                                .padding(7)
                        }
                } else {
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(iconColor)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 32,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 0
                            )
                            .fill(backgroundColor)
                            .overlay {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 32,
                                    bottomLeadingRadius: 32,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0
                                )
                                .strokeBorder(innerBorderColor, lineWidth: 4)
                            }
                        )
                }
            }
        }
        .buttonStyle(.animagicPress)
        .accessibilityLabel(isOpen ? "Close backpack" : "Open backpack")
        .padding(.trailing, isOpen ? -20 : -4)
    }
}

struct BackpackSidebarViewTest: View {
    @State private var isSidebarOpen: Bool = true
    
    let myTabs = ["Doodle", "3D"]
    let myInventory = [
        "Doodle": ["Doodle 1", "Doodle 2", "Doodle 3", "Doodle 4"],
        "3D": ["Model 1", "Model 2"],
    ]
    
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            HStack(spacing: 0) {
                Spacer()
                
                VStack {
                    Spacer()
                    BackpackTabButton(
                        isOpen: $isSidebarOpen,
                        backgroundColor: Color.Token.Border.primary,
                        iconColor: Color.Token.Icon.primary,
                        innerBorderColor: Color.Token.Border.outline
                    )
                    .padding(.bottom, 40)
                }
                .zIndex(1)

                if isSidebarOpen {
                    // 2. Lempar data (props) ke dalam komponen
                    BackpackSidebar(
                        tabs: myTabs,
                        items: myInventory,
                        onItemTapped: { selectedItem in
                            // Lakukan sesuatu saat item di dalam sidebar diklik
                            print("User menekan: \(selectedItem)")
                        }
                    )
                    .frame(width: 250)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }
}

#Preview("Backpack Sidebar") {
    BackpackSidebarViewTest()
}
