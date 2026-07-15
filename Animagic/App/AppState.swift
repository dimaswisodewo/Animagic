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
    var createdAt: Date

    init(
        id: UUID = UUID(), name: String, drawing: PKDrawing,
        category: ArtworkCategory = .land,
        doodleClassification: DoodleClassification? = nil,
        doodleOverrideLabel: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id; self.name = name; self.drawing = drawing; self.category = category
        self.doodleClassification = doodleClassification; self.doodleOverrideLabel = doodleOverrideLabel
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
    private var modelContext: ModelContext?
    
    func clearDrawing() {
        drawing = PKDrawing()
    }

    func startNewDrawing() { drawing = PKDrawing() }

    func configurePersistence(with context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        let drawings = (try? context.fetch(FetchDescriptor<SavedDrawingRecord>(sortBy: [SortDescriptor(\SavedDrawingRecord.createdAt, order: .reverse)]))) ?? []
        savedDrawings = drawings.compactMap { $0.asValue() }
        let cutouts = (try? context.fetch(FetchDescriptor<CutoutAssetRecord>())) ?? []
        cutoutLibrary = cutouts.compactMap { $0.asValue() }
    }

    func addSavedDrawing(_ drawing: SavedDrawing) {
        savedDrawings.append(drawing)
        guard let modelContext else { return }
        modelContext.insert(SavedDrawingRecord(drawing)); saveContext()
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
        guard let record = savedDrawingRecord(withID: id) else { return }
        record.predictedLabel = classification?.label
        record.predictionConfidence = classification.map { Double($0.confidence) }
        record.overrideLabel = overrideLabel
        record.categoryRawValue = savedDrawings[index].category.rawValue
        saveContext()
    }

    func addCutout(_ asset: CutoutAsset) {
        cutoutLibrary.append(asset)
        guard let modelContext, let record = CutoutAssetRecord(asset) else { return }
        modelContext.insert(record); saveContext()
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

    private func savedDrawingRecord(withID id: UUID) -> SavedDrawingRecord? {
        try? modelContext?.fetch(FetchDescriptor<SavedDrawingRecord>()).first(where: { $0.id == id })
    }
    private func cutoutRecord(withID id: UUID) -> CutoutAssetRecord? {
        try? modelContext?.fetch(FetchDescriptor<CutoutAssetRecord>()).first(where: { $0.id == id })
    }
    private func saveContext() { try? modelContext?.save() }
}
