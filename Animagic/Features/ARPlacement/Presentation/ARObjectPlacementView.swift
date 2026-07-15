//
//  ARObjectPlacementView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import SwiftUI

struct ARObjectPlacementView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    let cutoutAssets: [CutoutAsset]
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var selectedSpawnMode = SpawnMode.plane
    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var deleteRequestID: UUID?
    @State private var placementStatus: ARPlacementStatus = .searching

    init(cutoutAssets: [CutoutAsset], initialCutoutID: CutoutAsset.ID? = nil) {
        self.cutoutAssets = cutoutAssets
        let selectedID = initialCutoutID ?? cutoutAssets.first?.id
        _selectedCutoutID = State(initialValue: selectedID)
        _selectedAnimalArchetype = State(
            initialValue: Self.suggestedArchetype(
                for: cutoutAssets.first(where: { $0.id == selectedID })
            ) ?? .fish
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ARObjectPlacementRealityView(
                cutoutAssets: cutoutAssets,
                selectedCutoutID: selectedCutoutID,
                spawnAnimalArchetype: selectedAnimalArchetype,
                selectedObjectAnimalArchetype: placedObjectSelection?.animalArchetype,
                selectedSpawnMode: selectedSpawnMode,
                selectedContentType: selectedContentType,
                selectedModelID: selectedModelID,
                placedObjectSelection: $placedObjectSelection,
                placementStatus: $placementStatus,
                deleteRequestID: deleteRequestID
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ARInstructionBanner(
                    contentType: selectedContentType,
                    spawnMode: selectedSpawnMode,
                    status: placementStatus
                )
                PlacementContentTypePicker(selection: $selectedContentType)
                if selectedContentType == .doodle {
                    SpawnModePicker(selection: $selectedSpawnMode)
                    if cutoutAssets.isEmpty {
                        EmptyDoodleLibraryMessage()
                    } else {
                        CutoutPicker(assets: cutoutAssets, selection: $selectedCutoutID)
                    }
                    if let selectedAsset = selectedCutoutAsset {
                        DoodleCorrectionMenu(asset: selectedAsset) { label in
                            artworkStore.updateCutoutOverride(id: selectedAsset.id, label: label)
                        }
                    }
                    AnimalArchetypePicker(selection: archetypeSelection)
                } else {
                    USDZModelPicker(selection: $selectedModelID)
                }
                if let placedObjectSelection {
                    SelectedObjectToolbar(title: placedObjectSelection.title) {
                        deleteRequestID = UUID()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AR Placement")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCutoutID) { _, selectedID in
            guard placedObjectSelection == nil,
                  let suggested = Self.suggestedArchetype(
                      for: cutoutAssets.first(where: { $0.id == selectedID })
                  ) else {
                return
            }
            selectedAnimalArchetype = suggested
        }
        .onChange(of: selectedCutoutAsset?.resolvedDoodleLabel) { _, _ in
            guard placedObjectSelection == nil,
                  let suggested = Self.suggestedArchetype(for: selectedCutoutAsset) else {
                return
            }
            selectedAnimalArchetype = suggested
        }
    }

    private var activeAnimalArchetype: AnimalArchetype {
        placedObjectSelection?.animalArchetype ?? selectedAnimalArchetype
    }

    private var selectedCutoutAsset: CutoutAsset? {
        if let selectedCutoutID {
            return cutoutAssets.first(where: { $0.id == selectedCutoutID })
        }
        return cutoutAssets.first
    }

    private var archetypeSelection: Binding<AnimalArchetype> {
        Binding(
            get: { placedObjectSelection?.animalArchetype ?? activeAnimalArchetype },
            set: { archetype in
                if let selection = placedObjectSelection,
                   selection.animalArchetype != nil {
                    placedObjectSelection = PlacedObjectSelection(
                        objectID: selection.objectID,
                        content: .doodle(archetype)
                    )
                } else {
                    selectedAnimalArchetype = archetype
                }
            }
        )
    }

    private static func suggestedArchetype(for asset: CutoutAsset?) -> AnimalArchetype? {
        guard let asset, let label = asset.resolvedDoodleLabel else {
            return nil
        }
        return AnimalArchetype(
            doodleLabel: label,
            confidence: asset.doodleOverrideLabel == nil ? asset.doodleClassification?.confidence ?? 0 : 1
        )
    }
}

struct DoodleCorrectionMenu: View {
    let asset: CutoutAsset
    let onOverride: (String?) -> Void

    var body: some View {
        Menu {
            Button("Use AI Suggestion") { onOverride(nil) }
            ForEach(DoodleSpecies.all, id: \.self) { label in
                Button(label.capitalized) { onOverride(label) }
            }
        } label: {
            Label(
                "Detected: \(asset.resolvedDoodleLabel?.capitalized ?? "Unknown")",
                systemImage: "wand.and.stars"
            )
            .font(.caption)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
