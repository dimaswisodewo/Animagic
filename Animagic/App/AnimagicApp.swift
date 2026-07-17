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
    private let modelContainer: ModelContainer
    @State private var router = NavigationRouter()
    @State private var drawingSession = DrawingSessionManager()
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
                .environmentObject(artworkStore)
        }
        .modelContainer(modelContainer)
    }
}
