//
//  ContentView.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 14/07/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NavigationRouter.self) private var router
    @Environment(DrawingSessionManager.self) private var drawingSession
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @State private var isAnimatingGraphics = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background Color
            Color.Token.Background.primary
                .ignoresSafeArea()
            
            // Background Graphics
            GeometryReader { geometry in
                let scale = min(geometry.size.width, geometry.size.height) / 1024

                TopRightGraphic(scale: scale)
                    .offset(
                        x: reduceMotion ? 0 : (isAnimatingGraphics ? -12 : 12),
                        y: reduceMotion ? 0 : (isAnimatingGraphics ? -10 : 10)
                    )
                    .animation(backgroundAnimation(duration: 4.2), value: isAnimatingGraphics)
                    .position(x: geometry.size.width - 50, y: 50)
                
                BottomLeftGraphic(scale: scale)
                    .offset(
                        x: reduceMotion ? 0 : (isAnimatingGraphics ? 12 : -12),
                        y: reduceMotion ? 0 : (isAnimatingGraphics ? 10 : -10)
                    )
                    .animation(backgroundAnimation(duration: 4.8), value: isAnimatingGraphics)
                    .position(x: 50, y: geometry.size.height - 50)

                HomeFloatingDecorations()
            }
            .ignoresSafeArea()
            .onAppear {
                isAnimatingGraphics = !reduceMotion
            }
            .onChange(of: reduceMotion) { _, shouldReduceMotion in
                isAnimatingGraphics = !shouldReduceMotion
            }
            
            // Main Content
            GeometryReader { geo in
                let titleSize = min(geo.size.width * 0.35, 150)

                VStack(spacing: 50) {
                    ZStack {
                        // Thick outline for "AniMagix"
                        ForEach(0..<12) { i in
                            Text("AniMagix")
                                .font(.custom("Belanosima-SemiBold", size: titleSize, relativeTo: .largeTitle))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .foregroundColor(.white)
                                .offset(
                                    x: CGFloat(cos(Double(i) * .pi / 6)) * 8,
                                    y: CGFloat(sin(Double(i) * .pi / 6)) * 8
                                )
                        }
                        
                        Text("AniMagix")
                            .font(.custom("Belanosima-SemiBold", size: titleSize, relativeTo: .largeTitle))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundColor(Color(Color.Palette.n70))
                    }

                    AnimagicIconButton(
                        icon: "play.fill",
                        backgroundColor: Color.Palette.o300,
                        iconColor: .white,
                        innerBorderColor: Color.Palette.o400
                    ) {
                        drawingSession.clearDrawing()
                        router.push(.arView(initialCutoutID: artworkStore.cutoutLibrary.last?.id))
                    }
                    .scaleEffect(2.0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            AnimagicIconButton(
                icon: "questionmark",
                backgroundColor: Color.Token.Button.success
            ) {
                router.push(.help)
            }
            .accessibilityLabel("Help")
            .accessibilityHint("Opens the AniMagix guide")
            .padding(24)
            
            // Floating Bottom Buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    AnimagicIconButton(
                        icon: "backpack.fill",
                        backgroundColor: Color(Color.Palette.n20),
                        iconColor: Color(Color.Palette.n70),
                        innerBorderColor: .black.opacity(0.2)
                    ) {
                        router.push(.backpack)
                    }
                    .padding(.trailing, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .withAppRouter()
        .alert(
            artworkStore.persistenceAlert?.title ?? "Artwork Couldn’t Be Updated",
            isPresented: persistenceAlertIsPresented,
            presenting: artworkStore.persistenceAlert
        ) { alert in
            Button("Cancel", role: .cancel) {
                artworkStore.persistenceAlert = nil
            }
            Button("Retry") {
                artworkStore.persistenceAlert = nil
                alert.retry()
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var persistenceAlertIsPresented: Binding<Bool> {
        Binding(
            get: { artworkStore.persistenceAlert != nil },
            set: { isPresented in
                if !isPresented {
                    artworkStore.persistenceAlert = nil
                }
            }
        )
    }

    private func backgroundAnimation(duration: Double) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}

struct TopRightGraphic: View {
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.05, green: 0.45, blue: 0.98)) // Blue
                .frame(width: 400 * scale, height: 400 * scale)
            
            // Geometric shapes inside blue circle
            HStack(spacing: 0) {
                Rectangle().fill(Color.white).frame(width: 60 * scale, height: 40 * scale)
                Rectangle().fill(Color.black).frame(width: 40 * scale, height: 40 * scale)
            }
            .rotationEffect(.degrees(45))
            .offset(x: -50 * scale, y: 50 * scale)
        }
    }
}

struct BottomLeftGraphic: View {
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.45, blue: 0.75)) // Pink
                .frame(width: 450 * scale, height: 450 * scale)
            
            // Geometric shapes inside pink circle
            VStack(spacing: 16 * scale) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.white).frame(width: 70 * scale, height: 50 * scale)
                    Rectangle().fill(Color.black).frame(width: 50 * scale, height: 50 * scale)
                    Rectangle().fill(Color.white).frame(width: 50 * scale, height: 50 * scale)
                    Rectangle().fill(Color.black).frame(width: 50 * scale, height: 50 * scale)
                }
                .rotationEffect(.degrees(-30))
                
                Circle()
                    .fill(Color.black)
                    .frame(width: 30 * scale, height: 30 * scale)
                    .offset(x: 60 * scale, y: 0)
            }
            .offset(x: 50 * scale, y: -50 * scale)
        }
    }
}


#if DEBUG
#Preview {
    ContentView()
        .environment(NavigationRouter())
        .environment(DrawingSessionManager())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
#endif
