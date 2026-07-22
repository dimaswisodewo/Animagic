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

struct BackpackCutoutItem: Identifiable {
    let cutout: CutoutAsset
    let title: String

    var id: CutoutAsset.ID { cutout.id }
}

enum ArtworkLibraryPresentation {
    static func displayName(for drawing: SavedDrawing) -> String {
        let name = drawing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled" : name
    }

    static func sortedDrawings(_ drawings: [SavedDrawing]) -> [SavedDrawing] {
        drawings.sorted { lhs, rhs in
            let nameComparison = displayName(for: lhs).localizedStandardCompare(displayName(for: rhs))
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func backpackCutoutItems(
        drawings: [SavedDrawing],
        cutouts: [CutoutAsset],
        temporaryCutoutID: CutoutAsset.ID? = nil
    ) -> [BackpackCutoutItem] {
        let cutoutsByDrawingID = Dictionary(
            cutouts.compactMap { cutout in
                cutout.sourceDrawingID.map { ($0, cutout) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        var items = sortedDrawings(drawings).compactMap { drawing in
            cutoutsByDrawingID[drawing.id].map {
                BackpackCutoutItem(cutout: $0, title: displayName(for: drawing))
            }
        }

        guard let temporaryCutoutID,
              !items.contains(where: { $0.id == temporaryCutoutID }),
              let temporaryCutout = cutouts.first(where: { $0.id == temporaryCutoutID }) else {
            return items
        }

        let recognizedTitle = temporaryCutout.resolvedDoodleLabel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        let temporaryTitle = recognizedTitle.flatMap { $0.isEmpty ? nil : $0 } ?? "Photo Cutout"
        items.insert(
            BackpackCutoutItem(
                cutout: temporaryCutout,
                title: temporaryTitle
            ),
            at: 0
        )
        return items
    }
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
