//
//  AnimagicApp.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import AniMagicCreation
import AniMagicDesignSystem
import AniMagicSupport
import SwiftUI

@main
@MainActor
struct AnimagicApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let creationRuntime: CreationRuntime
    @State private var router = NavigationRouter()
    @State private var drawingSession = DrawingSessionManager()
    @State private var haptics = HapticFeedbackManager()
    @State private var backgroundMusic = BackgroundMusicController()
    @State private var startupErrorMessage: String?
    @StateObject private var artworkStore: CreationLibraryStore

    init() {
        AniMagicDesignSystemModule.registerFonts()
        let runtime = CreationRuntime.openDefault()
        creationRuntime = runtime
        _startupErrorMessage = State(initialValue: runtime.startupIssue?.localizedDescription)
        _artworkStore = StateObject(wrappedValue: runtime.libraryStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .environment(drawingSession)
                .environment(haptics)
                .environment(backgroundMusic)
                .environmentObject(artworkStore)
                .onAppear(perform: activateAppServices)
                .alert(
                    "Creation Library Unavailable",
                    isPresented: Binding(
                        get: { startupErrorMessage != nil },
                        set: { if !$0 { startupErrorMessage = nil } }
                    )
                ) {
                    Button("Continue") { startupErrorMessage = nil }
                } message: {
                    Text(startupErrorMessage ?? "")
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        haptics.prepare()
                        backgroundMusic.activate()
                    case .inactive, .background:
                        haptics.shutdown()
                        backgroundMusic.deactivate()
                    @unknown default:
                        break
                    }
                }
        }
    }

    private func activateAppServices() {
        haptics.prepare()
        backgroundMusic.activate()
    }
}
