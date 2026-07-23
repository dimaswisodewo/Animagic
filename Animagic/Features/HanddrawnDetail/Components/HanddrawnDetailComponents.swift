//
//  HanddrawnDetailComponents.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 21/07/26.
//

import PencilKit
import SwiftUI

struct HanddrawnDetailHeader: View {
    @Binding var title: String
    let onTitleCommit: () -> Void
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
                innerBorderColor: .black.opacity(0.2),
                action: onBack
            )
            EditableDrawingTitleField(title: $title, onCommit: onTitleCommit)
                .frame(maxWidth: .infinity)
            AnimagicIconButton(
                icon: "camera.fill",
                backgroundColor: Color.Token.Button.secondary,
                innerBorderColor: .black.opacity(0.2),
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

private struct EditableDrawingTitleField: View {
    @Binding var title: String
    let onCommit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black.opacity(0.6))
            TextField("Drawing title", text: $title, prompt: Text("Untitled"))
                .font(.custom("Belanosima-Bold", size: 28))
                .foregroundStyle(.black)
                .lineLimit(1)
                .submitLabel(.done)
                .focused($isFocused)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.black.opacity(0.2), lineWidth: 4)
        }
        .onSubmit {
            isFocused = false
        }
        .onChange(of: isFocused) { wasFocused, isFocused in
            if wasFocused && !isFocused {
                onCommit()
            }
        }
        .accessibilityLabel("Drawing title")
        .accessibilityHint("Edit the drawing title")
    }
}

struct HanddrawnArtworkView: View {
    @Environment(\.displayScale) private var displayScale

    let drawing: PKDrawing

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if drawing.bounds.isEmpty {
                Text("Empty Drawing")
                    .font(.custom("Belanosima-Regular", size: 24))
                    .foregroundStyle(.gray)
            } else {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: displayScale))
                    .resizable()
                    .scaledToFit()
                    .padding(40)
            }
        }
    }
}
