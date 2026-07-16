//
//  ARObjectPlacementRealityView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARObjectPlacementRealityView: UIViewRepresentable {
    let cutoutAssets: [CutoutAsset]
    let selectedCutoutID: CutoutAsset.ID?
    let spawnAnimalArchetype: AnimalArchetype
    let selectedObjectAnimalArchetype: AnimalArchetype?
    let selectedSpawnMode: SpawnMode
    @Binding var placedObjectSelection: PlacedObjectSelection?
    let deleteRequestID: UUID?
    let retryRequestID: UUID?
    @Binding var sessionStatus: ARSessionStatus

    func makeCoordinator() -> ARSceneController {
        ARSceneController(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: spawnAnimalArchetype,
            selectedSpawnMode: selectedSpawnMode,
            onSelectionChanged: { selection in
                placedObjectSelection = selection
            },
            onStatusChanged: { status in
                sessionStatus = status
            }
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        context.coordinator.runSession(on: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.cutoutAssets = cutoutAssets
        context.coordinator.selectedCutoutID = selectedCutoutID
        context.coordinator.selectedAnimalArchetype = spawnAnimalArchetype
        context.coordinator.selectedSpawnMode = selectedSpawnMode
        context.coordinator.onSelectionChanged = { selection in
            placedObjectSelection = selection
        }
        context.coordinator.onStatusChanged = { status in
            sessionStatus = status
        }

        if let selectedObjectAnimalArchetype,
           context.coordinator.placedObjectSelection?.animalArchetype != selectedObjectAnimalArchetype {
            context.coordinator.setSelectedObjectAnimalArchetype(selectedObjectAnimalArchetype)
        }

        if let deleteRequestID,
           context.coordinator.handledDeleteRequestID != deleteRequestID {
            context.coordinator.handledDeleteRequestID = deleteRequestID
            context.coordinator.deleteSelectedObject()
        }

        if let retryRequestID,
           context.coordinator.handledRetryRequestID != retryRequestID {
            context.coordinator.handledRetryRequestID = retryRequestID
            context.coordinator.retrySession(on: arView)
        }
    }

    static func dismantleUIView(_ arView: ARView, coordinator: ARSceneController) {
        coordinator.stopAnimationLoop()
        arView.session.pause()
    }
}
