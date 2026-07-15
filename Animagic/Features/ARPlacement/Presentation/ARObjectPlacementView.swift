//
//  ARObjectPlacementView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import SwiftUI

struct ARObjectPlacementView: View {
    let cutoutAssets: [CutoutAsset]
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var selectedSpawnMode = SpawnMode.plane
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
                placedObjectSelection: $placedObjectSelection,
                placementStatus: $placementStatus,
                deleteRequestID: deleteRequestID
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ARInstructionBanner(spawnMode: selectedSpawnMode, status: placementStatus)
                SpawnModePicker(selection: $selectedSpawnMode)
                CutoutPicker(assets: cutoutAssets, selection: $selectedCutoutID)
                AnimalArchetypePicker(selection: archetypeSelection)
                if placedObjectSelection != nil {
                    SelectedObjectToolbar {
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
    }

    private var activeAnimalArchetype: AnimalArchetype {
        placedObjectSelection?.animalArchetype ?? selectedAnimalArchetype
    }

    private var archetypeSelection: Binding<AnimalArchetype> {
        Binding(
            get: { activeAnimalArchetype },
            set: { archetype in
                if let selection = placedObjectSelection {
                    placedObjectSelection = PlacedObjectSelection(
                        objectID: selection.objectID,
                        animalArchetype: archetype
                    )
                } else {
                    selectedAnimalArchetype = archetype
                }
            }
        )
    }

    private static func suggestedArchetype(for asset: CutoutAsset?) -> AnimalArchetype? {
        guard let classification = asset?.doodleClassification else {
            return nil
        }
        return AnimalArchetype(
            doodleLabel: classification.label,
            confidence: classification.confidence
        )
    }
}
