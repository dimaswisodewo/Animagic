//
//  VirtualRoomView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Combine
import CoreMotion
import RealityKit
import SwiftUI
import UIKit

struct VirtualRoomView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @State private var calibrationRequest = 0
    @State private var interactionMode = VirtualRoomInteractionMode.explore
    @State private var selectedSkybox = VirtualRoomSkybox.citrusOrchard
    @State private var skyboxLoadState = SkyboxLoadState.loading
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var selectedSpawnMode = SpawnMode.plane
    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var deleteRequestID: UUID?
    @State private var placementMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityRoomView(
                calibrationRequest: calibrationRequest,
                interactionMode: interactionMode,
                selectedSkybox: selectedSkybox,
                cutoutAssets: artworkStore.cutoutLibrary,
                selectedCutoutID: selectedCutoutID,
                spawnAnimalArchetype: selectedAnimalArchetype,
                selectedObjectAnimalArchetype: placedObjectSelection?.animalArchetype,
                selectedSpawnMode: selectedSpawnMode,
                selectedContentType: selectedContentType,
                selectedModelID: selectedModelID,
                placedObjectSelection: $placedObjectSelection,
                skyboxLoadState: $skyboxLoadState,
                placementMessage: $placementMessage,
                deleteRequestID: deleteRequestID,
                onInteractionModeChanged: { mode in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        interactionMode = mode
                    }
                }
            )
            .ignoresSafeArea()

            CinematicOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Header UI (Top overlays)
            VStack {
                HStack(alignment: .top) {
                    calibrationButton
                    
                    Spacer()
                    
                    // Floating Mode Pill (Explore vs Edit)
                    HStack(spacing: 0) {
                        ForEach(VirtualRoomInteractionMode.allCases) { mode in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    interactionMode = mode
                                }
                            } label: {
                                Label(mode.title, systemImage: mode.systemImageName)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(interactionMode == mode ? Color.accentColor : Color.clear)
                                    .foregroundStyle(interactionMode == mode ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 6)

                    Spacer()

                    skyboxMenu
                }
                .padding()
                
                // Floating Contextual Instructions
                if interactionMode == .edit {
                    ARInstructionBanner(
                        contentType: selectedContentType,
                        spawnMode: selectedSpawnMode,
                        status: editPlacementStatus
                    )
                    .padding(.top, 4)
                }

                if let skyboxErrorMessage {
                    Text(skyboxErrorMessage)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }

                Spacer()
            }

            // Bottom Edit Dock Layer
            if interactionMode == .edit {
                editControls
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            synchronizeCutoutSelection()
        }
        .onChange(of: artworkStore.cutoutLibrary.map(\.id)) { _, _ in
            synchronizeCutoutSelection()
        }
        .onChange(of: selectedCutoutID) { _, selectedID in
            guard placedObjectSelection == nil,
                  let suggested = suggestedArchetype(
                      for: artworkStore.cutoutLibrary.first(where: { $0.id == selectedID })
                  ) else {
                return
            }
            selectedAnimalArchetype = suggested
        }
        .onChange(of: selectedCutoutAsset?.resolvedDoodleLabel) { _, _ in
            guard placedObjectSelection == nil,
                  let suggested = suggestedArchetype(for: selectedCutoutAsset) else {
                return
            }
            selectedAnimalArchetype = suggested
        }
        .navigationTitle("Virtual Room")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var editPlacementStatus: ARPlacementStatus {
        if skyboxLoadState == .loading {
            return .loading("Loading Environment")
        }
        return .ready
    }

    private var calibrationButton: some View {
        Button {
            calibrationRequest += 1
        } label: {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Calibrate")
    }

    private var skyboxErrorMessage: String? {
        if case .failed(let message) = skyboxLoadState {
            return message
        }
        return nil
    }

    private var skyboxMenu: some View {
        Menu {
            Picker("Skybox", selection: $selectedSkybox) {
                ForEach(VirtualRoomSkybox.allCases) { skybox in
                    Text(skybox.title).tag(skybox)
                }
            }
        } label: {
            HStack(spacing: 6) {
                if skyboxLoadState == .loading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: skyboxLoadState.isFailure ? "exclamationmark.triangle" : "globe")
                        .font(.system(size: 14))
                }
                Text(selectedSkybox.title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose skybox")
    }

    @ViewBuilder
    private var editControls: some View {
        VStack(spacing: 12) {
            if let placedObjectSelection {
                SelectedObjectToolbar(title: placedObjectSelection.title) {
                    deleteRequestID = UUID()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Contextual adjustments for doodles
            if selectedContentType == .doodle && !artworkStore.cutoutLibrary.isEmpty {
                HStack(spacing: 16) {
                    // Compact Spawn Mode
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
                    
                    // Archetype Menu Picker
                    Menu {
                        Picker("Archetype", selection: archetypeSelection) {
                            ForEach(AnimalArchetype.allCases) { archetype in
                                Label(archetype.title, systemImage: archetype.systemImageName).tag(archetype)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedAnimalArchetype.systemImageName)
                            Text(selectedAnimalArchetype.title)
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    
                    // AI correction label menu
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

            // Edit Creation Dock
            VStack(spacing: 8) {
                PlacementContentTypePicker(selection: $selectedContentType)
                    .padding(.top, 6)
                
                if selectedContentType == .doodle {
                    if artworkStore.cutoutLibrary.isEmpty {
                        EmptyDoodleLibraryMessage()
                    } else {
                        CutoutPicker(assets: artworkStore.cutoutLibrary, selection: $selectedCutoutID)
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
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.3), value: selectedContentType)
        .animation(.smooth(duration: 0.25), value: placedObjectSelection)
    }

    private var selectedCutoutAsset: CutoutAsset? {
        if let selectedCutoutID {
            return artworkStore.cutoutLibrary.first(where: { $0.id == selectedCutoutID })
        }
        return artworkStore.cutoutLibrary.first
    }

    private var archetypeSelection: Binding<AnimalArchetype> {
        Binding(
            get: { placedObjectSelection?.animalArchetype ?? selectedAnimalArchetype },
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

    private func synchronizeCutoutSelection() {
        if let selectedCutoutID,
           artworkStore.cutoutLibrary.contains(where: { $0.id == selectedCutoutID }) {
            return
        }
        selectedCutoutID = artworkStore.cutoutLibrary.first?.id
        if let suggested = suggestedArchetype(for: artworkStore.cutoutLibrary.first) {
            selectedAnimalArchetype = suggested
        }
    }

    private func suggestedArchetype(for asset: CutoutAsset?) -> AnimalArchetype? {
        guard let asset, let label = asset.resolvedDoodleLabel else {
            return nil
        }
        return AnimalArchetype(
            doodleLabel: label,
            confidence: asset.doodleOverrideLabel == nil ? asset.doodleClassification?.confidence ?? 0 : 1
        )
    }
}

struct CinematicOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.18),
                    Color(red: 0.18, green: 0.11, blue: 0.06).opacity(0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.42)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )

            VStack {
                Rectangle()
                    .fill(.black.opacity(0.12))
                    .frame(height: 34)

                Spacer()

                Rectangle()
                    .fill(.black.opacity(0.12))
                    .frame(height: 34)
            }
        }
    }
}

#if DEBUG
#Preview {
    VirtualRoomView()
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
#endif
