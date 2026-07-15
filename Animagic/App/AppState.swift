import SwiftUI
import PencilKit
import Combine

enum NavigationRoute: Hashable {
    case canvas
    case arView
    case backpack
}

struct SavedDrawing: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var drawing: PKDrawing
    var category: String = "All" // Can be mapped to Skies, Underwater, Land if needed
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SavedDrawing, rhs: SavedDrawing) -> Bool {
        lhs.id == rhs.id
    }
}

class AppState: ObservableObject {
    @Published var drawing: PKDrawing = PKDrawing()
    @Published var savedDrawings: [SavedDrawing] = []
    @Published var navigationPath = NavigationPath()
    @Published var cutoutLibrary: [CutoutAsset] = []
    
    func clearDrawing() {
        drawing = PKDrawing()
    }
}
