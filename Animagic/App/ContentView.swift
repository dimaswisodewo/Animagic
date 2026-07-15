//
//  ContentView.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 14/07/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            ZStack {
                // Background Color
                Color(red: 1.0, green: 0.79, blue: 0.07) // Yellow #FFC812
                    .ignoresSafeArea()
                
                // Background Graphics
                GeometryReader { geometry in
                    TopRightGraphic()
                        .position(x: geometry.size.width - 50, y: 50)
                    
                    BottomLeftGraphic()
                        .position(x: 50, y: geometry.size.height - 50)
                }
                .ignoresSafeArea()
                
                // Main Content
                VStack(spacing: 20) {
                    Text("AniMagic")
                        .font(.custom("Belanosima-SemiBold", size: 150))
                        .foregroundColor(.black)
                        .padding(.bottom, 20)
                    
                    CustomButton(title: "Let's Draw!") {
                        // Drawing state can be kept or cleared depending on preference.
                        // For a fresh start, you might clear it, but typically "Draw More!" does that.
                        appState.navigationPath.append(NavigationRoute.canvas)
                    }
                    
                    CustomButton(title: "Magic Lens") {
                        appState.clearDrawing() // Magic Lens should start with blank canvas if they hit Draw More!
                        appState.navigationPath.append(NavigationRoute.arView)
                    }
                    
                    CustomButton(title: "My Backpack") {
                        appState.navigationPath.append(NavigationRoute.backpack)
                    }
                }
            }
            .navigationDestination(for: NavigationRoute.self) { route in
                switch route {
                case .canvas:
                    CanvasPageView()
                case .arView:
                    ARObjectPlacementView(cutoutAssets: appState.cutoutLibrary, initialCutoutID: appState.cutoutLibrary.last?.id)
                case .backpack:
                    BackpackPageView()
                }
            }
        }
        .environmentObject(appState)
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

#Preview {
    ContentView()
}
