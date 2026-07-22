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
    @State private var backgroundMusic = BackgroundMusicController()
    @StateObject private var artworkStore: ArtworkLibraryStore

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
                .environment(backgroundMusic)
                .environmentObject(artworkStore)
                .onAppear(perform: activateAppServices)
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
        .modelContainer(modelContainer)
    }

    private func activateAppServices() {
        haptics.prepare()
        backgroundMusic.activate()
    }
}
