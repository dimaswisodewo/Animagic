//
//  StandalonePlaceholderView.swift
//  AniMagic
//
//  Created by MorpKnight on 20/07/26.
//

import SwiftUI

struct StandalonePlaceholderView: View {
    @State private var isMenuExpanded = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background

            VStack(spacing: 0) {
                header

                Spacer()

                placeholderContent

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            expandableMenu
                .padding(.top, 20)
                .padding(.trailing, 24)
        }
        .preferredColorScheme(.light)
    }

    private var background: some View {
        AnimagicTheme.yellow
            .ignoresSafeArea()
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(AnimagicTheme.pink)
                    .frame(width: 250, height: 250)
                    .offset(x: -90, y: 90)
                    .opacity(0.85)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(AnimagicTheme.blue)
                    .frame(width: 210, height: 210)
                    .offset(x: 80, y: -100)
                    .opacity(0.9)
                    .allowsHitTesting(false)
            }
    }

    private var header: some View {
        Text("Placeholder")
            .font(.custom("Belanosima-SemiBold", size: 32, relativeTo: .title2))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var placeholderContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.dashed")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))

            Text("Your placeholder content goes here")
                .font(.custom("Belanosima-Regular", size: 28, relativeTo: .title3))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)

            Text("This page is intentionally standalone.")
                .font(.custom("Belanosima-Regular", size: 18, relativeTo: .body))
                .foregroundStyle(.black.opacity(0.65))
        }
        .padding(32)
        .frame(maxWidth: 420)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.black, lineWidth: 3)
        }
    }

    private var expandableMenu: some View {
        ExpandableActionMenu(
            isExpanded: $isMenuExpanded,
            items: [
                ExpandableActionMenuItem(
                    id: "dummy-one",
                    title: "Dummy One",
                    systemImage: "sparkles",
                    action: {}
                ),
                ExpandableActionMenuItem(
                    id: "dummy-two",
                    title: "Dummy Two",
                    systemImage: "wand.and.stars",
                    action: {}
                ),
                ExpandableActionMenuItem(
                    id: "dummy-three",
                    title: "Dummy Three",
                    systemImage: "circle.dotted",
                    action: {}
                )
            ]
        )
    }
}

#if DEBUG
#Preview {
    StandalonePlaceholderView()
}
#endif
