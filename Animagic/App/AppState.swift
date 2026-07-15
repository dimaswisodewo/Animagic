import SwiftUI
import PencilKit
import Combine
import SwiftData

enum NavigationRoute: Hashable {
    case canvas
    case arView
    case backpack
    case handdrawnDetail(SavedDrawing)
}

struct SavedDrawing: Identifiable, Hashable {
    let id: UUID
    var name: String
    var drawing: PKDrawing
    var category: ArtworkCategory
    var doodleClassification: DoodleClassification?
    var doodleOverrideLabel: String?
    var isNameManuallyEdited: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(), name: String, drawing: PKDrawing,
        category: ArtworkCategory = .land,
        doodleClassification: DoodleClassification? = nil,
        doodleOverrideLabel: String? = nil,
        isNameManuallyEdited: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id; self.name = name; self.drawing = drawing; self.category = category
        self.doodleClassification = doodleClassification; self.doodleOverrideLabel = doodleOverrideLabel
        self.isNameManuallyEdited = isNameManuallyEdited
        self.createdAt = createdAt
    }
    
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
    @Published var activeDrawingID: UUID?
    private var modelContext: ModelContext?
    
    func clearDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }

    func startNewDrawing() {
        drawing = PKDrawing()
        activeDrawingID = nil
    }

    func configurePersistence(with context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        let drawings = (try? context.fetch(FetchDescriptor<SavedDrawingRecord>(sortBy: [SortDescriptor(\SavedDrawingRecord.createdAt, order: .reverse)]))) ?? []
        savedDrawings = drawings.compactMap { $0.asValue() }
        let cutouts = (try? context.fetch(FetchDescriptor<CutoutAssetRecord>())) ?? []
        cutoutLibrary = cutouts.compactMap { $0.asValue() }
        migrateLegacyAutomaticNames()
    }

    func addSavedDrawing(_ drawing: SavedDrawing) {
        savedDrawings.append(drawing)
        guard let modelContext else { return }
        modelContext.insert(SavedDrawingRecord(drawing)); saveContext()
    }

    func saveActiveDrawing(
        name: String,
        drawing: PKDrawing,
        isNameManuallyEdited: Bool
    ) -> SavedDrawing {
        if let activeDrawingID,
           let index = savedDrawings.firstIndex(where: { $0.id == activeDrawingID }) {
            savedDrawings[index].drawing = drawing
            savedDrawings[index].isNameManuallyEdited = isNameManuallyEdited
            if isNameManuallyEdited || savedDrawings[index].name.isEmpty {
                savedDrawings[index].name = name
            }

            if let record = savedDrawingRecord(withID: activeDrawingID) {
                record.drawingData = drawing.dataRepresentation()
                record.isNameManuallyEdited = isNameManuallyEdited
                if isNameManuallyEdited || record.name.isEmpty {
                    record.name = name
                }
                saveContext()
            }
            self.drawing = drawing
            return savedDrawings[index]
        }

        let newDrawing = SavedDrawing(
            name: name,
            drawing: drawing,
            isNameManuallyEdited: isNameManuallyEdited
        )
        addSavedDrawing(newDrawing)
        activeDrawingID = newDrawing.id
        self.drawing = drawing
        return newDrawing
    }

    func removeSavedDrawing(id: UUID) {
        savedDrawings.removeAll { $0.id == id }
        if let record = savedDrawingRecord(withID: id) { modelContext?.delete(record); saveContext() }
    }

    func updateSavedDrawingClassification(id: UUID, classification: DoodleClassification?, overrideLabel: String? = nil) {
        guard let index = savedDrawings.firstIndex(where: { $0.id == id }) else { return }
        savedDrawings[index].doodleClassification = classification
        savedDrawings[index].doodleOverrideLabel = overrideLabel
        savedDrawings[index].category = .category(forDoodleLabel: overrideLabel ?? classification?.label)
        if !savedDrawings[index].isNameManuallyEdited {
            savedDrawings[index].name = automaticDrawingName(
                for: overrideLabel ?? classification?.label,
                excluding: id
            )
        }
        guard let record = savedDrawingRecord(withID: id) else { return }
        record.name = savedDrawings[index].name
        record.predictedLabel = classification?.label
        record.predictionConfidence = classification.map { Double($0.confidence) }
        record.overrideLabel = overrideLabel
        record.categoryRawValue = savedDrawings[index].category.rawValue
        record.isNameManuallyEdited = savedDrawings[index].isNameManuallyEdited
        saveContext()
    }

    func addCutout(_ asset: CutoutAsset) {
        cutoutLibrary.append(asset)
        guard let modelContext, let record = CutoutAssetRecord(asset) else { return }
        modelContext.insert(record); saveContext()
    }

    func replaceCutout(_ asset: CutoutAsset, forDrawingID drawingID: UUID) {
        let existingAssets = cutoutLibrary.filter { $0.sourceDrawingID == drawingID }
        for existingAsset in existingAssets {
            removeCutout(existingAsset)
        }
        addCutout(asset)
    }

    func removeCutout(_ asset: CutoutAsset) {
        cutoutLibrary.removeAll { $0.id == asset.id }
        if let record = cutoutRecord(withID: asset.id) { modelContext?.delete(record); saveContext() }
    }

    func clearCutouts() -> [CutoutAsset] {
        let removed = cutoutLibrary; cutoutLibrary.removeAll()
        for asset in removed { if let record = cutoutRecord(withID: asset.id) { modelContext?.delete(record) } }
        saveContext(); return removed
    }

    func restoreCutouts(_ assets: [CutoutAsset]) {
        for asset in assets where !cutoutLibrary.contains(where: { $0.id == asset.id }) { addCutout(asset) }
    }

    func updateCutoutOverride(id: UUID, label: String?) {
        guard let index = cutoutLibrary.firstIndex(where: { $0.id == id }) else { return }
        let old = cutoutLibrary[index]
        cutoutLibrary[index] = CutoutAsset(id: old.id, sourceDrawingID: old.sourceDrawingID, image: old.image, originalSize: old.originalSize, doodleClassification: old.doodleClassification, doodleClassificationError: old.doodleClassificationError, doodleOverrideLabel: label)
        if let record = cutoutRecord(withID: id) { record.overrideLabel = label; saveContext() }
        if let sourceDrawingID = old.sourceDrawingID {
            updateSavedDrawingClassification(id: sourceDrawingID, classification: old.doodleClassification, overrideLabel: label)
        }
    }

    var activeDrawing: SavedDrawing? {
        guard let activeDrawingID else { return nil }
        return savedDrawings.first(where: { $0.id == activeDrawingID })
    }

    private func savedDrawingRecord(withID id: UUID) -> SavedDrawingRecord? {
        try? modelContext?.fetch(FetchDescriptor<SavedDrawingRecord>()).first(where: { $0.id == id })
    }
    private func cutoutRecord(withID id: UUID) -> CutoutAssetRecord? {
        try? modelContext?.fetch(FetchDescriptor<CutoutAssetRecord>()).first(where: { $0.id == id })
    }

    private func migrateLegacyAutomaticNames() {
        for drawing in savedDrawings where !drawing.isNameManuallyEdited && isPlaceholderName(drawing.name) {
            guard let index = savedDrawings.firstIndex(where: { $0.id == drawing.id }) else { continue }
            savedDrawings[index].name = automaticDrawingName(
                for: drawing.doodleOverrideLabel ?? drawing.doodleClassification?.label,
                excluding: drawing.id
            )
            if let record = savedDrawingRecord(withID: drawing.id) {
                record.name = savedDrawings[index].name
                record.isNameManuallyEdited = false
            }
        }
        saveContext()
    }

    private func automaticDrawingName(for label: String?, excluding id: UUID) -> String {
        let baseName = (label ?? "").trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let prefix = baseName.isEmpty ? "Drawing" : baseName
        var number = 1
        while savedDrawings.contains(where: {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare("\(prefix) #\(number)") == .orderedSame
        }) {
            number += 1
        }
        return "\(prefix) #\(number)"
    }

    private func isPlaceholderName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty || normalized.caseInsensitiveCompare("Untitled") == .orderedSame
    }

    private func saveContext() { try? modelContext?.save() }
}
