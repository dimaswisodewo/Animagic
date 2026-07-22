//
//  ArtworkLibraryStore.swift
//  AniMagic
//
//  Created by dimaswisodewo on 15/07/26.
//

import Combine
import Foundation
import PencilKit

struct PersistenceAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let retry: @MainActor () -> Void
}

@MainActor
final class ArtworkLibraryStore: ObservableObject {
    @Published private(set) var savedDrawings: [SavedDrawing] = []
    @Published private(set) var cutoutLibrary: [CutoutAsset] = []
    @Published var persistenceAlert: PersistenceAlert?

    private let repository: any ArtworkRepository

    init(repository: any ArtworkRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        do {
            let snapshot = try repository.loadSnapshot()
            var normalizedDrawings = snapshot.drawings
            var migratedDrawings: [SavedDrawing] = []

            for index in normalizedDrawings.indices {
                guard !normalizedDrawings[index].isNameManuallyEdited,
                      DrawingNameGenerator.isPlaceholder(normalizedDrawings[index].name) else {
                    continue
                }
                normalizedDrawings[index].name = DrawingNameGenerator.automaticName(
                    for: normalizedDrawings[index].doodleOverrideLabel
                        ?? normalizedDrawings[index].doodleClassification?.label,
                    excluding: normalizedDrawings[index].id,
                    in: normalizedDrawings
                )
                migratedDrawings.append(normalizedDrawings[index])
            }

            try repository.upsertDrawings(migratedDrawings)
            savedDrawings = normalizedDrawings
            cutoutLibrary = snapshot.cutouts
            persistenceAlert = nil
        } catch {
            present(error, retry: { [weak self] in self?.reload() })
        }
    }

    func drawing(id: UUID?) -> SavedDrawing? {
        guard let id else { return nil }
        return savedDrawings.first(where: { $0.id == id })
    }

    func cutout(forDrawingID drawingID: UUID) -> CutoutAsset? {
        cutoutLibrary.first { $0.sourceDrawingID == drawingID }
    }

    func classificationError(forDrawingID drawingID: UUID) -> String? {
        cutout(forDrawingID: drawingID)?.doodleClassificationError
    }

    func saveActiveDrawing(
        id: UUID?,
        name: String,
        drawing: PKDrawing,
        isNameManuallyEdited: Bool,
        onSuccess: @escaping @MainActor (SavedDrawing) -> Void
    ) {
        var savedDrawing: SavedDrawing
        if let id, let existing = self.drawing(id: id) {
            savedDrawing = existing
            savedDrawing.drawing = drawing
            savedDrawing.isNameManuallyEdited = isNameManuallyEdited
            if isNameManuallyEdited || savedDrawing.name.isEmpty {
                savedDrawing.name = name
            }
        } else {
            savedDrawing = SavedDrawing(
                id: id ?? UUID(),
                name: name,
                drawing: drawing,
                isNameManuallyEdited: isNameManuallyEdited
            )
        }

        do {
            try repository.upsertDrawing(savedDrawing)
            if let index = savedDrawings.firstIndex(where: { $0.id == savedDrawing.id }) {
                savedDrawings[index] = savedDrawing
            } else {
                savedDrawings.append(savedDrawing)
            }
            persistenceAlert = nil
            onSuccess(savedDrawing)
        } catch {
            present(error) { [weak self] in
                self?.saveActiveDrawing(
                    id: savedDrawing.id,
                    name: savedDrawing.name,
                    drawing: savedDrawing.drawing,
                    isNameManuallyEdited: savedDrawing.isNameManuallyEdited,
                    onSuccess: onSuccess
                )
            }
        }
    }

    func deleteDrawing(id: UUID, onSuccess: @escaping @MainActor () -> Void = {}) {
        do {
            try repository.deleteDrawing(id: id)
            savedDrawings.removeAll { $0.id == id }
            cutoutLibrary.removeAll { $0.sourceDrawingID == id }
            persistenceAlert = nil
            onSuccess()
        } catch {
            present(error) { [weak self] in
                self?.deleteDrawing(id: id, onSuccess: onSuccess)
            }
        }
    }

    func renameDrawing(
        id: UUID,
        to name: String,
        onFailure: @escaping @MainActor () -> Void = {},
        onSuccess: @escaping @MainActor (SavedDrawing) -> Void = { _ in }
    ) {
        guard var drawing = drawing(id: id) else {
            onFailure()
            persistenceAlert = PersistenceAlert(
                title: "Drawing Couldn’t Be Renamed",
                message: "This drawing is no longer available. Reload your artwork and try again.",
                retry: { [weak self] in self?.reload() }
            )
            return
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            onFailure()
            return
        }
        guard normalizedName != drawing.name else {
            onSuccess(drawing)
            return
        }

        drawing.name = normalizedName
        drawing.isNameManuallyEdited = true

        do {
            try repository.upsertDrawing(drawing)
            if let index = savedDrawings.firstIndex(where: { $0.id == id }) {
                savedDrawings[index] = drawing
            }
            persistenceAlert = nil
            onSuccess(drawing)
        } catch {
            onFailure()
            present(error) { [weak self] in
                self?.renameDrawing(
                    id: id,
                    to: normalizedName,
                    onFailure: onFailure,
                    onSuccess: onSuccess
                )
            }
        }
    }

    func persistClassifiedCutout(
        _ cutout: CutoutAsset,
        forDrawingID drawingID: UUID,
        replacingExistingCutouts: Bool,
        onFailure: @escaping @MainActor () -> Void = {},
        onSuccess: @escaping @MainActor (SavedDrawing) -> Void
    ) {
        guard var drawing = drawing(id: drawingID) else {
            onFailure()
            persistenceAlert = PersistenceAlert(
                title: "Artwork Couldn’t Be Updated",
                message: "This draft is no longer available. Reload your artwork and try again.",
                retry: { [weak self] in self?.reload() }
            )
            return
        }
        drawing.doodleClassification = cutout.doodleClassification
        drawing.doodleOverrideLabel = cutout.doodleOverrideLabel
        let resolvedLabel = cutout.doodleOverrideLabel ?? cutout.doodleClassification?.label
        drawing.category = .category(forDoodleLabel: resolvedLabel)
        if !drawing.isNameManuallyEdited {
            drawing.name = DrawingNameGenerator.automaticName(
                for: resolvedLabel,
                excluding: drawing.id,
                in: savedDrawings
            )
        }

        do {
            try repository.persistClassifiedCutout(
                drawing: drawing,
                cutout: cutout,
                replacingExistingCutouts: replacingExistingCutouts
            )
            if let index = savedDrawings.firstIndex(where: { $0.id == drawing.id }) {
                savedDrawings[index] = drawing
            }
            if replacingExistingCutouts {
                cutoutLibrary.removeAll { $0.sourceDrawingID == drawingID }
            }
            if let index = cutoutLibrary.firstIndex(where: { $0.id == cutout.id }) {
                cutoutLibrary[index] = cutout
            } else {
                cutoutLibrary.append(cutout)
            }
            persistenceAlert = nil
            onSuccess(drawing)
        } catch {
            onFailure()
            present(error) { [weak self] in
                self?.persistClassifiedCutout(
                    cutout,
                    forDrawingID: drawingID,
                    replacingExistingCutouts: replacingExistingCutouts,
                    onFailure: onFailure,
                    onSuccess: onSuccess
                )
            }
        }
    }

    func addCutouts(_ cutouts: [CutoutAsset]) {
        guard !cutouts.isEmpty else { return }
        do {
            try repository.upsertCutouts(cutouts)
            for cutout in cutouts where !cutoutLibrary.contains(where: { $0.id == cutout.id }) {
                cutoutLibrary.append(cutout)
            }
            persistenceAlert = nil
        } catch {
            present(error) { [weak self] in self?.addCutouts(cutouts) }
        }
    }

    func removeCutout(_ cutout: CutoutAsset) {
        do {
            try repository.deleteCutout(id: cutout.id)
            cutoutLibrary.removeAll { $0.id == cutout.id }
            persistenceAlert = nil
        } catch {
            present(error) { [weak self] in self?.removeCutout(cutout) }
        }
    }

    func clearCutouts(onSuccess: @escaping @MainActor ([CutoutAsset]) -> Void) {
        let removed = cutoutLibrary
        do {
            try repository.deleteAllCutouts()
            cutoutLibrary.removeAll()
            persistenceAlert = nil
            onSuccess(removed)
        } catch {
            present(error) { [weak self] in self?.clearCutouts(onSuccess: onSuccess) }
        }
    }

    func restoreCutouts(_ cutouts: [CutoutAsset]) {
        do {
            try repository.upsertCutouts(cutouts)
            for cutout in cutouts where !cutoutLibrary.contains(where: { $0.id == cutout.id }) {
                cutoutLibrary.append(cutout)
            }
            persistenceAlert = nil
        } catch {
            present(error) { [weak self] in self?.restoreCutouts(cutouts) }
        }
    }

    func updateCutoutOverride(id: UUID, label: String?) {
        guard let cutoutIndex = cutoutLibrary.firstIndex(where: { $0.id == id }) else { return }
        let oldCutout = cutoutLibrary[cutoutIndex]
        let updatedCutout = CutoutAsset(
            id: oldCutout.id,
            sourceDrawingID: oldCutout.sourceDrawingID,
            image: oldCutout.image,
            originalSize: oldCutout.originalSize,
            doodleClassification: oldCutout.doodleClassification,
            doodleClassificationError: oldCutout.doodleClassificationError,
            doodleOverrideLabel: label
        )

        var updatedDrawing: SavedDrawing?
        if var drawing = drawing(id: oldCutout.sourceDrawingID) {
            drawing.doodleClassification = oldCutout.doodleClassification
            drawing.doodleOverrideLabel = label
            drawing.category = .category(forDoodleLabel: label ?? oldCutout.doodleClassification?.label)
            if !drawing.isNameManuallyEdited {
                drawing.name = DrawingNameGenerator.automaticName(
                    for: label ?? oldCutout.doodleClassification?.label,
                    excluding: drawing.id,
                    in: savedDrawings
                )
            }
            updatedDrawing = drawing
        }

        do {
            try repository.updateCutout(updatedCutout, sourceDrawing: updatedDrawing)
            cutoutLibrary[cutoutIndex] = updatedCutout
            if let updatedDrawing,
               let drawingIndex = savedDrawings.firstIndex(where: { $0.id == updatedDrawing.id }) {
                savedDrawings[drawingIndex] = updatedDrawing
            }
            persistenceAlert = nil
        } catch {
            present(error) { [weak self] in self?.updateCutoutOverride(id: id, label: label) }
        }
    }

    private func present(_ error: Error, retry: @escaping @MainActor () -> Void) {
        let message = (error as? LocalizedError)?.errorDescription
            ?? "The change couldn’t be saved. Your previous data is unchanged."
        persistenceAlert = PersistenceAlert(
            title: "Artwork Couldn’t Be Updated",
            message: message,
            retry: retry
        )
    }
}

#if DEBUG
@MainActor
final class PreviewArtworkRepository: ArtworkRepository {
    private var drawings: [SavedDrawing]
    private var cutouts: [CutoutAsset]

    init(drawings: [SavedDrawing] = [], cutouts: [CutoutAsset] = []) {
        self.drawings = drawings
        self.cutouts = cutouts
    }

    func loadSnapshot() throws -> ArtworkSnapshot {
        ArtworkSnapshot(drawings: drawings, cutouts: cutouts)
    }

    func upsertDrawing(_ drawing: SavedDrawing) throws {
        if let index = drawings.firstIndex(where: { $0.id == drawing.id }) {
            drawings[index] = drawing
        } else {
            drawings.append(drawing)
        }
    }

    func upsertDrawings(_ drawings: [SavedDrawing]) throws {
        for drawing in drawings { try upsertDrawing(drawing) }
    }

    func deleteDrawing(id: UUID) throws {
        drawings.removeAll { $0.id == id }
        cutouts.removeAll { $0.sourceDrawingID == id }
    }

    func persistClassifiedCutout(
        drawing: SavedDrawing,
        cutout: CutoutAsset,
        replacingExistingCutouts: Bool
    ) throws {
        try upsertDrawing(drawing)
        if replacingExistingCutouts {
            cutouts.removeAll { $0.sourceDrawingID == drawing.id }
        }
        upsertCutout(cutout)
    }

    private func upsertCutout(_ cutout: CutoutAsset) {
        if let index = cutouts.firstIndex(where: { $0.id == cutout.id }) {
            cutouts[index] = cutout
        } else {
            cutouts.append(cutout)
        }
    }

    func deleteCutout(id: UUID) throws {
        cutouts.removeAll { $0.id == id }
    }

    func deleteAllCutouts() throws {
        cutouts.removeAll()
    }

    func upsertCutouts(_ cutouts: [CutoutAsset]) throws {
        for cutout in cutouts { upsertCutout(cutout) }
    }

    func updateCutout(_ cutout: CutoutAsset, sourceDrawing: SavedDrawing?) throws {
        upsertCutout(cutout)
        if let sourceDrawing { try upsertDrawing(sourceDrawing) }
    }
}
#endif
