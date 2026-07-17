import Foundation
import PencilKit

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
        id: UUID = UUID(),
        name: String,
        drawing: PKDrawing,
        category: ArtworkCategory = .land,
        doodleClassification: DoodleClassification? = nil,
        doodleOverrideLabel: String? = nil,
        isNameManuallyEdited: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.drawing = drawing
        self.category = category
        self.doodleClassification = doodleClassification
        self.doodleOverrideLabel = doodleOverrideLabel
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

struct ArtworkSnapshot {
    let drawings: [SavedDrawing]
    let cutouts: [CutoutAsset]
}

enum DrawingNameGenerator {
    static func automaticName(
        for label: String?,
        excluding id: UUID,
        in drawings: [SavedDrawing]
    ) -> String {
        let baseName = (label ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        let prefix = baseName.isEmpty ? "Drawing" : baseName
        var number = 1

        while drawings.contains(where: {
            $0.id != id
                && $0.name.localizedCaseInsensitiveCompare("\(prefix) #\(number)") == .orderedSame
        }) {
            number += 1
        }

        return "\(prefix) #\(number)"
    }

    static func isPlaceholder(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty
            || normalized.caseInsensitiveCompare("Untitled") == .orderedSame
    }
}
