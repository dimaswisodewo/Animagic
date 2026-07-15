import Combine
import Foundation
import PhotosUI
import _PhotosUI_SwiftUI

@MainActor
final class CutoutLibraryViewModel: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published private(set) var processedCount = 0
    @Published private(set) var totalSelectionCount = 0
    @Published var errorMessage: String?

    private let processor: any CutoutProcessing

    init(processor: (any CutoutProcessing)? = nil) {
        self.processor = processor ?? VisionForegroundCutoutProcessor()
    }

    func processImages(from items: [PhotosPickerItem]) async -> [CutoutAsset] {
        errorMessage = nil
        guard !items.isEmpty else {
            return []
        }

        isProcessing = true
        processedCount = 0
        totalSelectionCount = items.count
        defer {
            isProcessing = false
            totalSelectionCount = 0
            processedCount = 0
        }

        var failures = 0
        var newAssets: [CutoutAsset] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CutoutProcessingError.invalidImage
                }
                let processor = self.processor
                let cutout = try await Task.detached(priority: .userInitiated) {
                    try await processor.makeCutout(from: data)
                }.value
                newAssets.append(cutout)
            } catch is CancellationError {
                break
            } catch {
                failures += 1
            }
            processedCount += 1
        }

        if failures > 0 {
            errorMessage = "\(failures) image\(failures == 1 ? "" : "s") could not be converted into cutout objects."
        }
        
        return newAssets
    }
}
