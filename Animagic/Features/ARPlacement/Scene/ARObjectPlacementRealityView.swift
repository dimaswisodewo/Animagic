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
    let spawnAnimalLocomotion: AnimalLocomotion
    let selectedObjectAnimalLocomotion: AnimalLocomotion?
    let selectedSpawnMode: SpawnMode
    let selectedContentType: PlacementContentType
    let selectedModelID: PlaceableUSDZModel.ID?
    @Binding var placedObjectSelection: PlacedObjectSelection?
    @Binding var placementStatus: ARPlacementStatus
    let deleteRequestID: UUID?

    func makeCoordinator() -> ARSceneController {
        ARSceneController(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalLocomotion: spawnAnimalLocomotion,
            selectedSpawnMode: selectedSpawnMode,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            onSelectionChanged: { selection in
                Task { @MainActor in
                    if placedObjectSelection != selection {
                        placedObjectSelection = selection
                    }
                }
            },
            onPlacementStatusChanged: { status in
                Task { @MainActor in
                    if placementStatus != status {
                        placementStatus = status
                    }
                }
            }
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        let coaching = ARCoachingOverlayView()
        coaching.goal = .horizontalPlane
        coaching.session = arView.session
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: arView.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])

        context.coordinator.runSession(on: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.cutoutAssets = cutoutAssets
        context.coordinator.selectedCutoutID = selectedCutoutID
        context.coordinator.selectedAnimalLocomotion = spawnAnimalLocomotion
        context.coordinator.selectedSpawnMode = selectedSpawnMode
        context.coordinator.selectedContentType = selectedContentType
        context.coordinator.selectedModelID = selectedModelID
        context.coordinator.onSelectionChanged = { selection in
            Task { @MainActor in
                if placedObjectSelection != selection {
                    placedObjectSelection = selection
                }
            }
        }
        context.coordinator.onPlacementStatusChanged = { status in
            Task { @MainActor in
                if placementStatus != status {
                    placementStatus = status
                }
            }
        }

        if let selectedObjectAnimalLocomotion,
           context.coordinator.placedObjectSelection?.animalLocomotion != selectedObjectAnimalLocomotion {
            context.coordinator.setSelectedObjectAnimalLocomotion(selectedObjectAnimalLocomotion)
        }

        if let deleteRequestID,
           context.coordinator.handledDeleteRequestID != deleteRequestID {
            context.coordinator.handledDeleteRequestID = deleteRequestID
            context.coordinator.deleteSelectedObject()
        }
    }

    static func dismantleUIView(_ arView: ARView, coordinator: ARSceneController) {
        coordinator.stopAnimationLoop()
        arView.session.pause()
    }
}
