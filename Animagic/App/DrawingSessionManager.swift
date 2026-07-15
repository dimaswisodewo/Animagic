import Observation
import PencilKit

@MainActor
@Observable
final class DrawingSessionManager {
    var drawing = PKDrawing()
    var activeDrawingID: UUID?

    func startNewDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }

    func clearDrawing() {
        startNewDrawing()
    }
}
