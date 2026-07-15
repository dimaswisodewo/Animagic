import PencilKit
import SwiftUI

enum NavigationRoute: Hashable {
    case canvas
    case arView
    case backpack
    case handdrawnDetail(UUID)
}

@MainActor
final class AppState: ObservableObject {
    @Published var drawing: PKDrawing = PKDrawing()
    @Published var navigationPath = NavigationPath()
    @Published var activeDrawingID: UUID?
    
    func clearDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }

    func startNewDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }
}
