//
//  HomeFloatingDecorations.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 21/07/26.
//

import SwiftUI

struct HomeFloatingDecorations: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 430

            ZStack {
                HomeFloatingDecoration(
                    kind: .star,
                    color: Color.Palette.o200,
                    size: 54 * scale,
                    bounceHeight: 18 * scale,
                    horizontalDrift: 8 * scale,
                    rotation: 12,
                    duration: 2.8,
                    delay: 0.1,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.17, y: geometry.size.height * 0.19)

                HomeFloatingDecoration(
                    kind: .bubble,
                    color: Color.Palette.b300,
                    size: 46 * scale,
                    bounceHeight: 24 * scale,
                    horizontalDrift: 10 * scale,
                    rotation: -8,
                    duration: 3.6,
                    delay: 0.6,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.34, y: geometry.size.height * 0.13)

                HomeFloatingDecoration(
                    kind: .heart,
                    color: Color.Palette.r200,
                    size: 48 * scale,
                    bounceHeight: 20 * scale,
                    horizontalDrift: 7 * scale,
                    rotation: 10,
                    duration: 3.1,
                    delay: 0.25,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.86, y: geometry.size.height * 0.31)

                HomeFloatingDecoration(
                    kind: .diamond,
                    color: Color.Palette.g200,
                    size: 42 * scale,
                    bounceHeight: 22 * scale,
                    horizontalDrift: 9 * scale,
                    rotation: 16,
                    duration: 3.9,
                    delay: 0.8,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.13, y: geometry.size.height * 0.64)

                HomeFloatingDecoration(
                    kind: .confetti,
                    color: Color.Palette.o300,
                    size: 54 * scale,
                    bounceHeight: 17 * scale,
                    horizontalDrift: 12 * scale,
                    rotation: 18,
                    duration: 2.6,
                    delay: 0.45,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.87, y: geometry.size.height * 0.64)

                HomeFloatingDecoration(
                    kind: .sparkle,
                    color: Color.Palette.b200,
                    size: 50 * scale,
                    bounceHeight: 19 * scale,
                    horizontalDrift: 8 * scale,
                    rotation: -14,
                    duration: 3.4,
                    delay: 1.0,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.71, y: geometry.size.height * 0.84)

                HomeFloatingDecoration(
                    kind: .bubble,
                    color: Color.Palette.y100,
                    size: 38 * scale,
                    bounceHeight: 15 * scale,
                    horizontalDrift: 11 * scale,
                    rotation: -12,
                    duration: 3.0,
                    delay: 0.75,
                    isAnimating: isAnimating
                )
                .position(x: geometry.size.width * 0.34, y: geometry.size.height * 0.84)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            isAnimating = !shouldReduceMotion
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HomeFloatingDecoration: View {
    enum Kind {
        case bubble
        case confetti
        case diamond
        case heart
        case sparkle
        case star
    }

    let kind: Kind
    let color: Color
    let size: CGFloat
    let bounceHeight: CGFloat
    let horizontalDrift: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double
    let isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        decoration
            .frame(width: size, height: size)
            .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1.03 : 0.97))
            .rotationEffect(
                .degrees(reduceMotion ? 0 : (isAnimating ? rotation : -rotation) * 0.6)
            )
            .offset(
                x: reduceMotion ? 0 : (isAnimating ? horizontalDrift : -horizontalDrift) * 0.6,
                y: reduceMotion ? 0 : (isAnimating ? -bounceHeight : bounceHeight) * 0.6
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: duration)
                        .delay(delay)
                        .repeatForever(autoreverses: true),
                value: isAnimating
            )
    }

    @ViewBuilder
    private var decoration: some View {
        switch kind {
        case .bubble:
            Circle()
                .fill(color.opacity(0.26))
                .overlay {
                    Circle()
                        .stroke(color, lineWidth: max(2, size * 0.08))
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.75))
                        .frame(width: size * 0.22, height: size * 0.22)
                        .offset(x: size * 0.2, y: size * 0.16)
                }

        case .confetti:
            Capsule()
                .fill(color)
                .frame(width: size * 0.28, height: size * 0.9)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.8), lineWidth: max(2, size * 0.05))
                }

        case .diamond:
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(color)
                .padding(size * 0.12)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.16)
                        .stroke(.white.opacity(0.85), lineWidth: max(2, size * 0.06))
                        .padding(size * 0.12)
                }
                .rotationEffect(.degrees(45))

        case .heart:
            ZStack {
                Image(systemName: "heart")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.8))

                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(size * 0.08)
            }

        case .sparkle:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)

        case .star:
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .overlay {
                    Image(systemName: "star")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(size * 0.08)
                }
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.Token.Background.primary
            .ignoresSafeArea()

        HomeFloatingDecorations()
    }
}
#endif
