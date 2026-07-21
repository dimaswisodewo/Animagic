//
//  ExpandableActionMenu.swift
//  AniMagic
//
//  Created by MorpKnight on 21/07/26.
//

import SwiftUI

struct ExpandableActionMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct ExpandableActionMenu: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var isExpanded: Bool

    private let items: [ExpandableActionMenuItem]

    init(
        isExpanded: Binding<Bool>,
        items: [ExpandableActionMenuItem]
    ) {
        _isExpanded = isExpanded
        self.items = items
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isExpanded {
                actionButtons
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.96, anchor: .trailing).combined(with: .opacity)
                    )
            }

            Button {
                withAnimation(animation) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "ellipsis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 58, height: 58)
                    .background(AnimagicTheme.orange, in: Circle())
                    .overlay(Circle().stroke(.black, lineWidth: 3))
                    .contentShape(Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.animagicPress)
            .accessibilityLabel(isExpanded ? "Close expandable menu" : "Open expandable menu")
            .accessibilityHint("Shows additional actions")
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                Button(action: item.action) {
                    Label(item.title, systemImage: item.systemImage)
                        .font(.custom("Belanosima-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.9), in: Capsule())
                        .overlay(Capsule().stroke(.black, lineWidth: 2))
                }
                .buttonStyle(.animagicPress)
            }
        }
    }

    private var animation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.28, dampingFraction: 0.95)
    }
}

#if DEBUG
private struct ExpandableActionMenuPreview: View {
    @State private var isExpanded = false

    var body: some View {
        ExpandableActionMenu(
            isExpanded: $isExpanded,
            items: [
                ExpandableActionMenuItem(
                    id: "sparkles",
                    title: "Dummy One",
                    systemImage: "sparkles",
                    action: {}
                ),
                ExpandableActionMenuItem(
                    id: "wand",
                    title: "Dummy Two",
                    systemImage: "wand.and.stars",
                    action: {}
                )
            ]
        )
        .padding()
        .background(AnimagicTheme.yellow)
    }
}

#Preview {
    ExpandableActionMenuPreview()
}
#endif
