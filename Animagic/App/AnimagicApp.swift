//
//  AnimagicApp.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import SwiftData
import SwiftUI

@main
@MainActor
struct AnimagicApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer
    @State private var router = NavigationRouter()
    @State private var drawingSession = DrawingSessionManager()
    @State private var haptics = HapticFeedbackManager()
    @StateObject private var artworkStore: ArtworkLibraryStore
    @State private var hasStartedMusic = false

    init() {
        do {
            let container = try ModelContainer(
                for: SavedDrawingRecord.self,
                CutoutAssetRecord.self
            )
            modelContainer = container
            _artworkStore = StateObject(
                wrappedValue: ArtworkLibraryStore(
                    repository: SwiftDataArtworkRepository(context: container.mainContext)
                )
            )
        } catch {
            fatalError("Unable to create the artwork store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .environment(drawingSession)
                .environment(haptics)
                .environmentObject(artworkStore)
                .onAppear(perform: startMusicIfNeeded)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        haptics.prepare()
                        if hasStartedMusic {
                            AudioManager.shared.resumeMusic()
                        } else {
                            startMusicIfNeeded()
                        }
                    case .inactive, .background:
                        haptics.shutdown()
                        AudioManager.shared.pauseMusic()
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    private func startMusicIfNeeded() {
        haptics.prepare()
        guard !hasStartedMusic else { return }
        AudioManager.shared.setup()
        AudioManager.shared.playMusic(.bgmHome)
        hasStartedMusic = true
    }
}
