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

            // Floating Top HUD
            VStack {
                ARInstructionBanner(
                    contentType: selectedContentType,
                    spawnMode: selectedSpawnMode,
                    status: placementStatus
                )
                .padding(.top, 10)
                Spacer()
            }

            // Bottom Controls Layer
            VStack(spacing: 12) {
                if let placedObjectSelection {
                    SelectedObjectToolbar(title: placedObjectSelection.title) {
                        deleteRequestID = UUID()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Contextual Doodle adjustments capsule
                if selectedContentType == .doodle && !cutoutAssets.isEmpty {
                    HStack(spacing: 16) {
                        // Compact Spawn Mode Toggle
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                selectedSpawnMode = selectedSpawnMode == .plane ? .cameraRoam : .plane
                            }
                        } label: {
                            Image(systemName: selectedSpawnMode.systemImageName)
                                .font(.footnote.bold())
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32, height: 32)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())
                        }
                        
                        // Compact Archetype Dropdown
                        Menu {
                            Picker("Archetype", selection: archetypeSelection) {
                                ForEach(AnimalArchetype.allCases) { archetype in
                                    Label(archetype.title, systemImage: archetype.systemImageName).tag(archetype)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: activeAnimalArchetype.systemImageName)
                                Text(activeAnimalArchetype.title)
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        
                        // AI Label override menu
                        if let selectedAsset = selectedCutoutAsset {
                            Menu {
                                Button("Use AI Suggestion") {
                                    artworkStore.updateCutoutOverride(id: selectedAsset.id, label: nil)
                                }
                                ForEach(DoodleSpecies.all, id: \.self) { label in
                                    Button(label.capitalized) {
                                        artworkStore.updateCutoutOverride(id: selectedAsset.id, label: label)
                                    }
                                }
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .font(.footnote)
                                    .foregroundStyle(selectedAsset.doodleOverrideLabel != nil ? Color.accentColor : Color.primary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Core Creation Dock
                VStack(spacing: 8) {
                    PlacementContentTypePicker(selection: $selectedContentType)
                        .padding(.top, 6)
                    
                    if selectedContentType == .doodle {
                        if cutoutAssets.isEmpty {
                            EmptyDoodleLibraryMessage()
                        } else {
                            CutoutPicker(assets: cutoutAssets, selection: $selectedCutoutID)
                        }
                    } else {
                        USDZModelPicker(selection: $selectedModelID)
                    }
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.15), radius: 10)
            }
            .padding()
        }
        .animation(.smooth(duration: 0.3), value: selectedContentType)
        .animation(.smooth(duration: 0.25), value: placedObjectSelection)
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
