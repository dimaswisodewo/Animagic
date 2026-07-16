//
//  ARObjectPlacementView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import SwiftUI

struct ARObjectPlacementView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let cutoutAssets: [CutoutAsset]
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedAnimalArchetype = AnimalArchetype.generic
    @State private var selectedSpawnMode = SpawnMode.plane
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var deleteRequestID: UUID?
    @State private var retryRequestID: UUID?
    @State private var sessionStatus: ARSessionStatus = .searching

    init(cutoutAssets: [CutoutAsset], initialCutoutID: CutoutAsset.ID? = nil) {
        self.cutoutAssets = cutoutAssets
        let selectedID = initialCutoutID ?? cutoutAssets.first?.id
        _selectedCutoutID = State(initialValue: selectedID)
        _selectedAnimalArchetype = State(
            initialValue: Self.suggestedArchetype(
                for: cutoutAssets.first(where: { $0.id == selectedID })
            ) ?? .generic
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
                deleteRequestID: deleteRequestID,
                retryRequestID: retryRequestID,
                sessionStatus: $sessionStatus
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ARInstructionBanner(status: sessionStatus, spawnMode: selectedSpawnMode)
                SpawnModePicker(selection: $selectedSpawnMode)
                CutoutPicker(assets: cutoutAssets, selection: $selectedCutoutID)
                if let selectedAsset = selectedCutoutAsset {
                    DoodleCorrectionMenu(asset: selectedAsset) { label in
                        appState.updateCutoutOverride(id: selectedAsset.id, label: label)
                    }
                }
                AnimalArchetypePicker(selection: archetypeSelection)
                if placedObjectSelection != nil {
                    SelectedObjectToolbar {
                        deleteRequestID = UUID()
                    }
                }
            }
            .padding()

            if sessionStatus.isBlockingOverlay {
                ARSessionStatusOverlay(
                    status: sessionStatus,
                    onRetry: { retryRequestID = UUID() },
                    onBack: { dismiss() }
                )
                .zIndex(2)
            }
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
        guard let asset, let label = asset.resolvedDoodleLabel else {
            return nil
        }
        return AnimalArchetype(
            doodleLabel: label,
            confidence: asset.doodleOverrideLabel == nil ? asset.doodleClassification?.confidence ?? 0 : 1
        )
    }
}

private struct DoodleCorrectionMenu: View {
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
