//
//  ContentView.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 14/07/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(DrawingSessionManager.self) private var drawingSession
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @State private var isAnimatingGraphics = false
    
    var body: some View {
        ZStack {
            ZStack {
                // Background Color
                Color(red: 1.0, green: 0.79, blue: 0.07) // Yellow #FFC812
                    .ignoresSafeArea()
                
                // Background Graphics
                GeometryReader { geometry in
                    TopRightGraphic()
                        .offset(x: isAnimatingGraphics ? -30 : 20)
                        .animation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .offset(y: isAnimatingGraphics ? -20 : 25)
                        .animation(.easeInOut(duration: 4.7).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .position(x: geometry.size.width - 50, y: 50)
                    
                    BottomLeftGraphic()
                        .offset(x: isAnimatingGraphics ? 25 : -15)
                        .animation(.easeInOut(duration: 3.7).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .offset(y: isAnimatingGraphics ? 30 : -20)
                        .animation(.easeInOut(duration: 2.9).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .position(x: 50, y: geometry.size.height - 50)
                        
                    TopLeftGraphic()
                        .offset(x: isAnimatingGraphics ? 15 : -25)
                        .animation(.easeInOut(duration: 4.1).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .offset(y: isAnimatingGraphics ? -30 : 15)
                        .animation(.easeInOut(duration: 3.3).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .position(x: 50, y: 150)
                        
                    BottomRightGraphic()
                        .offset(x: isAnimatingGraphics ? -20 : 30)
                        .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .offset(y: isAnimatingGraphics ? 25 : -30)
                        .animation(.easeInOut(duration: 4.9).repeatForever(autoreverses: true), value: isAnimatingGraphics)
                        .position(x: geometry.size.width - 50, y: geometry.size.height - 150)
                }
                .ignoresSafeArea()
                .onAppear {
                    isAnimatingGraphics = true
                }
                
                // Main Content
                VStack(spacing: 20) {
                    Text("AniMagic")
                        .font(.custom("Belanosima-SemiBold", size: 150))
                        .foregroundColor(.black)
                        .padding(.bottom, 20)
                    
                    CustomButton(title: "Let's Draw!") {
                        drawingSession.startNewDrawing()
                        router.push(.canvas)
                    }
                    
                    CustomButton(title: "Magic Lens") {
                        drawingSession.clearDrawing()
                        router.push(.arView(initialCutoutID: artworkStore.cutoutLibrary.last?.id))
                    }

                    CustomButton(title: "Virtual Room") {
                        router.push(.virtualRoom)
                    }
                    
                    CustomButton(title: "My Backpack") {
                        router.push(.backpack)
                    }
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
}

struct TopRightGraphic: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.05, green: 0.45, blue: 0.98)) // Blue
                .frame(width: 400, height: 400)
            
            // Geometric shapes inside blue circle
            HStack(spacing: 0) {
                Rectangle().fill(Color.white).frame(width: 60, height: 40)
                Rectangle().fill(Color.black).frame(width: 40, height: 40)
            }
            .rotationEffect(.degrees(45))
            .offset(x: -50, y: 50)
        }
    }
}

struct BottomLeftGraphic: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.45, blue: 0.75)) // Pink
                .frame(width: 450, height: 450)
            
            // Geometric shapes inside pink circle
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.white).frame(width: 70, height: 50)
                    Rectangle().fill(Color.black).frame(width: 50, height: 50)
                    Rectangle().fill(Color.white).frame(width: 50, height: 50)
                    Rectangle().fill(Color.black).frame(width: 50, height: 50)
                }
                .rotationEffect(.degrees(-30))
                
                Circle()
                    .fill(Color.black)
                    .frame(width: 30, height: 30)
                    .offset(x: 60, y: 0)
            }
            .offset(x: 50, y: -50)
        }
    }
}

struct TopLeftGraphic: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                .frame(width: 300, height: 300)
            
            // Geometric shapes inside orange circle
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(Color.white).frame(width: 30, height: 30)
                    Circle().fill(Color.black).frame(width: 30, height: 30)
                }
                HStack(spacing: 8) {
                    Circle().fill(Color.black).frame(width: 30, height: 30)
                    Circle().fill(Color.white).frame(width: 30, height: 30)
                }
            }
            .rotationEffect(.degrees(15))
            .offset(x: 30, y: 30)
        }
    }
}

struct BottomRightGraphic: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 350, height: 350)
                .overlay(Circle().stroke(Color.black, lineWidth: 10))
            
            // Geometric shapes inside
            HStack(spacing: -10) {
                Rectangle().fill(Color(red: 0.05, green: 0.45, blue: 0.98)).frame(width: 50, height: 100)
                Rectangle().fill(Color(red: 1.0, green: 0.45, blue: 0.75)).frame(width: 50, height: 100)
                Rectangle().fill(Color.black).frame(width: 50, height: 100)
            }
            .rotationEffect(.degrees(-25))
            .offset(x: -40, y: -40)
        }
    }
}

#Preview {
    ContentView()
        .environment(NavigationRouter())
        .environment(DrawingSessionManager())
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
