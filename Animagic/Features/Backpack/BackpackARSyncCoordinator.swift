//
//  BackpackARSyncCoordinator.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class BackpackARSyncCoordinator {
    private(set) var completedCount = 0
    private(set) var totalCount = 0

    @ObservationIgnored
    private let classificationCoordinator = DoodleClassificationCoordinator()
    @ObservationIgnored
    private var pendingDrawings: [SavedDrawing] = []
    @ObservationIgnored
    private var renderScale: CGFloat = 1
    @ObservationIgnored
    private var artworkStore: ArtworkLibraryStore?
    @ObservationIgnored
    private var completion: (@MainActor () -> Void)?
    @ObservationIgnored
    private var generation = UUID()

    var isPreparing: Bool {
        totalCount > 0
    }

    func prepareMissingCutouts(
        drawings: [SavedDrawing],
        cutouts: [CutoutAsset],
        renderScale: CGFloat,
        artworkStore: ArtworkLibraryStore,
        completion: @escaping @MainActor () -> Void
    ) {
        guard !isPreparing else { return }

        let missingDrawings = BackpackARPreparationPlanner().missingDrawings(
            drawings: drawings,
            cutouts: cutouts
        )

        guard !missingDrawings.isEmpty else {
            completion()
            return
        }

        generation = UUID()
        completedCount = 0
        totalCount = missingDrawings.count
        pendingDrawings = missingDrawings
        self.renderScale = renderScale
        self.artworkStore = artworkStore
        self.completion = completion
        prepareNext(generation: generation)
    }

    func cancel() {
        generation = UUID()
        classificationCoordinator.cancel()
        reset()
    }

    private func prepareNext(generation currentGeneration: UUID) {
        guard generation == currentGeneration else { return }
        guard !pendingDrawings.isEmpty else {
            let completion = completion
            reset()
            completion?()
            return
        }

        let drawing = pendingDrawings.removeFirst()
        classificationCoordinator.start(
            drawing: drawing.drawing,
            sourceDrawingID: drawing.id,
            renderScale: renderScale
        ) { [weak self] cutout in
            guard let self,
                  self.generation == currentGeneration,
                  let artworkStore = self.artworkStore else { return }

            artworkStore.persistClassifiedCutout(
                cutout,
                forDrawingID: drawing.id,
                replacingExistingCutouts: false,
                onFailure: { [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    self.generation = UUID()
                    self.classificationCoordinator.cancel()
                    self.reset()
                }
            ) { [weak self] _ in
                guard let self, self.generation == currentGeneration else { return }
                self.completedCount += 1
                self.prepareNext(generation: currentGeneration)
            }
        }
    }

    private func reset() {
        completedCount = 0
        totalCount = 0
        pendingDrawings.removeAll()
        artworkStore = nil
        completion = nil
    }
}
