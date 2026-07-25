//
//  CreationDrawing.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Foundation
import PencilKit

public struct CreationDrawing: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var drawing: PKDrawing
    public var category: CreationCategory
    public var doodleClassification: DoodleClassification?
    public var doodleOverrideLabel: String?
    public var isNameManuallyEdited: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        drawing: PKDrawing,
        category: CreationCategory = .land,
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: CreationDrawing, rhs: CreationDrawing) -> Bool {
        lhs.id == rhs.id
    }
}

struct CreationLibrarySnapshot {
    public let drawings: [CreationDrawing]
    public let cutouts: [CreationPlayableAsset]
}

public struct BackpackCutoutItem: Identifiable {
    public let cutout: CreationPlayableAsset
    public let title: String

    public var id: CreationPlayableAsset.ID { cutout.id }
}

public enum CreationLibraryPresentation {
    public static func displayName(for drawing: CreationDrawing) -> String {
        let name = drawing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled" : name
    }

    public static func sortedDrawings(_ drawings: [CreationDrawing]) -> [CreationDrawing] {
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

    public static func backpackCutoutItems(
        drawings: [CreationDrawing],
        cutouts: [CreationPlayableAsset],
        temporaryCutoutID: CreationPlayableAsset.ID? = nil
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
    public static func automaticName(
        for label: String?,
        excluding id: UUID,
        in drawings: [CreationDrawing]
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

    public static func isPlaceholder(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty
            || normalized.caseInsensitiveCompare("Untitled") == .orderedSame
    }
}
