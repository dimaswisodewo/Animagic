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
    var onItemTapped: ((String) -> Void)? = nil
    
    @State private var selectedTab: String
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    init(tabs: [String], items: [String: [String]], onItemTapped: ((String) -> Void)? = nil) {
        self.tabs = tabs
        self.items = items
        self.onItemTapped = onItemTapped
        _selectedTab = State(initialValue: tabs.first ?? "")
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(isSelected ? .white : Color.Token.Button.secondary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.Token.Button.secondary : Color.Token.Card.primary)
                            )
                            .padding(4)
                            .background(
                                Capsule()
                                    .fill(Color.Token.Background.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.Token.Button.disabled)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(10)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns) {
                    let currentItems = items[selectedTab] ?? []
                    
                    ForEach(currentItems, id: \.self) { item in
                        Button(action: {
                            onItemTapped?(item)
                        }) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.Token.Background.surface)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    VStack {
                                        Image(systemName: "square")
                                            .font(.system(size: 40))
                                            .foregroundColor(Color.Token.Text.secondary)
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .background(Color.Token.Background.primary)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white, lineWidth: 6)
        )
    }
}

struct BackpackTabButton: View {
    @Binding var isOpen: Bool
    
    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .white
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isOpen.toggle()
            }
        }) {
            Image(systemName: isOpen ? "chevron.right" : "backpack.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(iconColor)
                .padding(.vertical, 20)
                .padding(.horizontal, 18)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(backgroundColor)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 28,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .strokeBorder(innerBorderColor, lineWidth: 4)
                    )
                )
                .padding(.trailing, -4)
        }
        .buttonStyle(.plain)
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
