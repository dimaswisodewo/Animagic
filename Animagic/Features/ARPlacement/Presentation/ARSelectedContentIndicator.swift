//
//  ARSelectedContentIndicator.swift
//  AniMagic
//
//  Created by MorpKnight on 22/07/26.
//

import SwiftUI

struct ARSelectedContentIndicator<Preview: View>: View {
    let kindTitle: String
    let title: String
    let accentColor: Color
    @ViewBuilder let preview: Preview

    var body: some View {
        HStack(spacing: 12) {
            preview
                .frame(width: 52, height: 52)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.16))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accentColor, lineWidth: 3)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Selected \(kindTitle)")
                    .font(.custom("Belanosima-SemiBold", size: 14, relativeTo: .caption))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)

                Text(title)
                    .font(.custom("Belanosima-SemiBold", size: 21, relativeTo: .headline))
                    .foregroundStyle(AnimagicTheme.darkNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 4)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white, AnimagicTheme.blue)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 250, alignment: .leading)
        .frame(minHeight: 76, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AnimagicTheme.darkNavy, lineWidth: 3)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected \(kindTitle), \(title)")
        .accessibilityAddTraits(.isStaticText)
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.gray
        ARSelectedContentIndicator(
            kindTitle: "Doodle",
            title: "My Fish",
            accentColor: AnimagicTheme.orange
        ) {
            Image(systemName: "fish.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AnimagicTheme.darkNavy)
        }
    }
}
#endif
