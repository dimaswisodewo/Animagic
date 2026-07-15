//
//  AnimagicApp.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import SwiftUI
import SwiftData

@main
struct AnimagicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SavedDrawingRecord.self, CutoutAssetRecord.self])
    }
}
