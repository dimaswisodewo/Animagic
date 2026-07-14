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

    init(cutoutAssets: [CutoutAsset], initialCutoutID: CutoutAsset.ID? = nil) {
        self.cutoutAssets = cutoutAssets
        _selectedCutoutID = State(initialValue: initialCutoutID ?? cutoutAssets.first?.id)
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
                deleteRequestID: deleteRequestID
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ARInstructionBanner(spawnMode: selectedSpawnMode)
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
}
