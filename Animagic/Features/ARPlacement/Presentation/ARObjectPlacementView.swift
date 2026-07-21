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
    @State private var selectedAnimalLocomotion = AnimalLocomotion.generic
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
        _selectedAnimalLocomotion = State(
            initialValue: Self.suggestedLocomotion(
                for: cutoutAssets.first(where: { $0.id == selectedID })
            ) ?? .generic
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ARObjectPlacementRealityView(
                cutoutAssets: cutoutAssets,
                selectedCutoutID: selectedCutoutID,
                spawnAnimalLocomotion: selectedAnimalLocomotion,
                selectedObjectAnimalLocomotion: placedObjectSelection?.animalLocomotion,
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
                        
                        // Compact Movement Dropdown
                        Menu {
                            Picker("Movement", selection: locomotionSelection) {
                                ForEach(AnimalLocomotion.allCases) { locomotion in
                                    Label(locomotion.title, systemImage: locomotion.systemImageName).tag(locomotion)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: activeAnimalLocomotion.systemImageName)
                                Text(activeAnimalLocomotion.title)
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
                                ForEach(DoodleSpecies.allCases) { species in
                                    Button(species.title) {
                                        artworkStore.updateCutoutOverride(id: selectedAsset.id, label: species.rawValue)
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
                  let suggested = Self.suggestedLocomotion(
                      for: cutoutAssets.first(where: { $0.id == selectedID })
                  ) else {
                return
            }
            selectedAnimalLocomotion = suggested
        }
        .onChange(of: selectedCutoutAsset?.resolvedDoodleLabel) { _, _ in
            guard placedObjectSelection == nil,
                  let suggested = Self.suggestedLocomotion(for: selectedCutoutAsset) else {
                return
            }
            selectedAnimalLocomotion = suggested
        }
    }

    private var activeAnimalLocomotion: AnimalLocomotion {
        placedObjectSelection?.animalLocomotion ?? selectedAnimalLocomotion
    }

    private var selectedCutoutAsset: CutoutAsset? {
        if let selectedCutoutID {
            return cutoutAssets.first(where: { $0.id == selectedCutoutID })
        }
        return cutoutAssets.first
    }

    private var locomotionSelection: Binding<AnimalLocomotion> {
        Binding(
            get: { placedObjectSelection?.animalLocomotion ?? activeAnimalLocomotion },
            set: { locomotion in
                if let selection = placedObjectSelection,
                   selection.animalLocomotion != nil {
                    placedObjectSelection = PlacedObjectSelection(
                        objectID: selection.objectID,
                        content: .doodle(locomotion)
                    )
                } else {
                    selectedAnimalLocomotion = locomotion
                }
            }
        )
    }

    private static func suggestedLocomotion(for asset: CutoutAsset?) -> AnimalLocomotion? {
        AnimalMotionProfileResolver.profile(for: asset).locomotion
    }
}
