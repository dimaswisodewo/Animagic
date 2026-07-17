//
//  RealityRoomView.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 16/07/26.
//

import RealityKit
import SwiftUI

struct RealityRoomView: UIViewRepresentable {
    let calibrationRequest: Int
    let interactionMode: VirtualRoomInteractionMode
    let selectedSkybox: VirtualRoomSkybox
    let cutoutAssets: [CutoutAsset]
    let selectedCutoutID: CutoutAsset.ID?
    let spawnAnimalArchetype: AnimalArchetype
    let selectedObjectAnimalArchetype: AnimalArchetype?
    let selectedSpawnMode: SpawnMode
    let selectedContentType: PlacementContentType
    let selectedModelID: PlaceableUSDZModel.ID?
    @Binding var placedObjectSelection: PlacedObjectSelection?
    @Binding var skyboxLoadState: SkyboxLoadState
    @Binding var placementMessage: String?
    let deleteRequestID: UUID?
    var onInteractionModeChanged: ((VirtualRoomInteractionMode) -> Void)?

    func makeCoordinator() -> RoomCoordinator {
        RoomCoordinator(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: spawnAnimalArchetype,
            selectedSpawnMode: selectedSpawnMode,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            onSelectionChanged: updateSelection,
            onSkyboxLoadStateChanged: updateSkyboxLoadState,
            onPlacementMessageChanged: updatePlacementMessage,
            onInteractionModeChanged: onInteractionModeChanged
        )
    }

    func makeUIView(context: Context) -> ARView {
        context.coordinator.makeView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.handleCalibrationRequest(calibrationRequest)
        context.coordinator.update(
            interactionMode: interactionMode,
            skybox: selectedSkybox,
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: spawnAnimalArchetype,
            selectedObjectAnimalArchetype: selectedObjectAnimalArchetype,
            selectedSpawnMode: selectedSpawnMode,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            deleteRequestID: deleteRequestID,
            onSelectionChanged: updateSelection,
            onSkyboxLoadStateChanged: updateSkyboxLoadState,
            onPlacementMessageChanged: updatePlacementMessage
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: RoomCoordinator) {
        coordinator.stop()
    }

    private func updateSelection(_ selection: PlacedObjectSelection?) {
        Task { @MainActor in
            if placedObjectSelection != selection {
                placedObjectSelection = selection
            }
        }
    }

    private func updateSkyboxLoadState(_ state: SkyboxLoadState) {
        Task { @MainActor in
            if skyboxLoadState != state {
                skyboxLoadState = state
            }
        }
    }

    private func updatePlacementMessage(_ message: String?) {
        Task { @MainActor in
            placementMessage = message
        }
    }
}
