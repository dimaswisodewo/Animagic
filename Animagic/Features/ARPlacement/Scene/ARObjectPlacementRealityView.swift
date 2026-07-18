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
    let selectedContentType: PlacementContentType
    let selectedModelID: PlaceableUSDZModel.ID?
    @Binding var placedObjectSelection: PlacedObjectSelection?
    @Binding var placementStatus: ARPlacementStatus
    let deleteRequestID: UUID?
    let retryRequestID: UUID?
    @Binding var sessionStatus: ARSessionStatus

    func makeCoordinator() -> ARSceneController {
        ARSceneController(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: spawnAnimalArchetype,
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
            },
            onStatusChanged: { status in
                Task { @MainActor in
                    if sessionStatus != status {
                        sessionStatus = status
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
        context.coordinator.selectedAnimalArchetype = spawnAnimalArchetype
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
        context.coordinator.onStatusChanged = { status in
            Task { @MainActor in
                if sessionStatus != status {
                    sessionStatus = status
                }
            }
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
