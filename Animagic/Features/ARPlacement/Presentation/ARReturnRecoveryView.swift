//
//  ARReturnRecoveryView.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 22/07/26.
//

import SwiftUI

struct ARTrackingReadiness: Equatable {
    let isTrackingNormal: Bool
    let hasSurface: Bool

    static let unavailable = Self(isTrackingNormal: false, hasSurface: false)

    var allowsInteraction: Bool {
        isTrackingNormal && hasSurface
    }
}

struct ARReturnRecoveryState: Equatable {
    enum Phase: Equatable {
        case inactive
        case recovering
        case fallbackActions
    }

    private(set) var readiness = ARTrackingReadiness.unavailable
    private(set) var phase = Phase.inactive

    var allowsInteraction: Bool {
        readiness.allowsInteraction && phase == .inactive
    }

    var showsRecoveryOverlay: Bool {
        phase != .inactive
    }

    var showsFallbackActions: Bool {
        phase == .fallbackActions
    }

    mutating func updateReadiness(_ readiness: ARTrackingReadiness) {
        self.readiness = readiness
        if readiness.allowsInteraction, phase != .inactive {
            phase = .inactive
        }
    }

    mutating func requireRecovery() {
        phase = readiness.allowsInteraction ? .inactive : .recovering
    }

    mutating func revealFallbackActions() {
        guard phase == .recovering else { return }
        phase = .fallbackActions
    }

    mutating func keepTrying() {
        phase = readiness.allowsInteraction ? .inactive : .recovering
    }
}

struct ARReturnRecoveryView: View {
    let showsActions: Bool
    let onKeepTrying: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.Token.Background.primary
                .opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(Color.Palette.n70)

                Text("Finding Your Scene")
                    .font(.custom("Belanosima-SemiBold", size: 40, relativeTo: .title))
                    .foregroundStyle(Color.Palette.n70)
                    .multilineTextAlignment(.center)

                Text("Point your device back at the original area and move slowly.")
                    .font(.custom("Belanosima-Regular", size: 22, relativeTo: .body))
                    .foregroundStyle(Color.Palette.n70)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                ProgressView()
                    .tint(Color.Palette.n70)

                if showsActions {
                    HStack(spacing: 12) {
                        AnimagicLabelButton(
                            title: "Exit AR",
                            icon: "xmark",
                            backgroundColor: Color.Palette.n50,
                            action: onExit
                        )

                        AnimagicLabelButton(
                            title: "Keep Trying",
                            icon: "arrow.clockwise",
                            backgroundColor: AnimagicTheme.blue,
                            innerBorderColor: Color.Palette.b400,
                            action: onKeepTrying
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Finding your AR scene")
    }
}
