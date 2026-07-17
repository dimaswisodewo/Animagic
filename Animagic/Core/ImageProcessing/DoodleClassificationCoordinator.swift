//
//  DoodleClassificationCoordinator.swift
//  AniMagic
//
//  Created by MorpKnight on 17/07/26.
//

import Foundation
import Observation
import PencilKit

enum DoodleClassificationState: Equatable {
    case idle
    case running
    case succeeded(UUID)
    case failed(String, UUID?)
    case cancelled
}

@MainActor
@Observable
final class DoodleClassificationCoordinator {
    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var generation = UUID()

    private(set) var state: DoodleClassificationState = .idle

    var isRunning: Bool {
        state == .running
    }

    func start(
        drawing: PKDrawing,
        sourceDrawingID: UUID,
        completion: @escaping @MainActor (CutoutAsset) -> Void
    ) {
        cancel(markAsCancelled: false)
        let currentGeneration = UUID()
        generation = currentGeneration
        state = .running

        let raster: DrawingRaster
        do {
            raster = try DrawingRasterizer.rasterize(drawing)
        } catch {
            let fallbackImage = drawing.image(from: drawing.bounds, scale: 1)
            let fallback = CutoutAsset(
                sourceDrawingID: sourceDrawingID,
                image: fallbackImage,
                originalSize: drawing.bounds.size,
                doodleClassificationError: error.localizedDescription
            )
            state = .failed(error.localizedDescription, fallback.id)
            completion(fallback)
            return
        }

        task = Task { [weak self] in
            let startedAt = DispatchTime.now().uptimeNanoseconds
            let cutout = await Task.detached(priority: .userInitiated) {
                ClassifiedCutoutFactory().makeCutout(
                    from: raster.image,
                    originalSize: raster.contentSize,
                    sourceDrawingID: sourceDrawingID
                )
            }.value
            let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
            let minimumDuration: UInt64 = 1_200_000_000
            if elapsed < minimumDuration {
                try? await Task.sleep(nanoseconds: minimumDuration - elapsed)
            }

            guard let self,
                  !Task.isCancelled,
                  self.generation == currentGeneration else {
                return
            }

            if let error = cutout.doodleClassificationError {
                self.state = .failed(error, cutout.id)
            } else {
                self.state = .succeeded(cutout.id)
            }
            completion(cutout)
        }
    }

    func cancel(markAsCancelled: Bool = true) {
        generation = UUID()
        task?.cancel()
        task = nil
        if markAsCancelled, state == .running {
            state = .cancelled
        }
    }
}
