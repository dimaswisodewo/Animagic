//
//  HanddrawnDetailComponents.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 21/07/26.
//

import PencilKit
import SwiftUI

struct HanddrawnDetailHeader: View {
    let title: String
    let onBack: () -> Void
    let onOpenAR: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            AnimagicIconButton(
                icon: "chevron.left",
                backgroundColor: Color(Color.Palette.n20),
                iconColor: Color(Color.Palette.n70),
                innerBorderColor: .clear,
                action: onBack
            )
            Text(title)
                .font(.custom("Belanosima-Bold", size: 28))
                .foregroundStyle(.black)
            Spacer()
            AnimagicIconButton(
                icon: "camera.fill",
                backgroundColor: Color.Token.Button.secondary,
                action: onOpenAR
            )
            AnimagicIconButton(
                icon: "square.and.arrow.up",
                backgroundColor: Color.Token.Button.primary,
                action: onShare
            )
            AnimagicIconButton(
                icon: "arrow.down.to.line",
                backgroundColor: Color.Token.Button.success,
                action: onSave
            )
            AnimagicIconButton(
                icon: "trash",
                backgroundColor: Color(Color.Palette.r300),
                action: onDelete
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AnimagicTheme.yellow)
    }
}

struct HanddrawnArtworkView: View {
    let drawing: PKDrawing

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if drawing.bounds.isEmpty {
                Text("Empty Drawing")
                    .font(.custom("Belanosima-Regular", size: 24))
                    .foregroundStyle(.gray)
            } else {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: 1))
                    .resizable()
                    .scaledToFit()
                    .padding(40)
            }
        }
    }
}
