//
//  ARSceneController.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import ARKit
import AVFoundation
import RealityKit
import UIKit

enum ARPlacementStatus: Equatable {
    case searching
    case ready
    case loading(String)
    case limited(String)
    case placed
    case failed(String)
}

@MainActor
final class ARSceneController: NSObject, SceneEditing, @preconcurrency ARSessionDelegate {
    var cutoutAssets: [CutoutAsset] {
        get { sceneEditor.cutoutAssets }
        set { sceneEditor.cutoutAssets = newValue }
    }
    var selectedCutoutID: CutoutAsset.ID? {
        get { sceneEditor.selectedCutoutID }
        set { sceneEditor.selectedCutoutID = newValue }
    }
    var selectedAnimalArchetype: AnimalArchetype {
        get { sceneEditor.selectedAnimalArchetype }
        set { sceneEditor.selectedAnimalArchetype = newValue }
    }
    var selectedSpawnMode: SpawnMode {
        get { sceneEditor.selectedSpawnMode }
        set { sceneEditor.selectedSpawnMode = newValue }
    }
    var selectedContentType: PlacementContentType {
        get { sceneEditor.selectedContentType }
        set { sceneEditor.selectedContentType = newValue }
    }
    var selectedModelID: PlaceableUSDZModel.ID? {
        get { sceneEditor.selectedModelID }
        set { sceneEditor.selectedModelID = newValue }
    }
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private let sceneEditor: CutoutSceneEditor
    private var detectedPlaneIDs: Set<UUID> = []
    private var statusResetWorkItem: DispatchWorkItem?
    var handledDeleteRequestID: UUID?
    var handledRetryRequestID: UUID?
    var onPlacementStatusChanged: ((ARPlacementStatus) -> Void)?
    private(set) var placementStatus: ARPlacementStatus = .searching
    private(set) var sessionStatus: ARSessionStatus = .searching
    var onStatusChanged: ((ARSessionStatus) -> Void)?

    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)? {
        didSet {
            sceneEditor.onSelectionChanged = onSelectionChanged
        }
    }

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedSpawnMode: SpawnMode,
        selectedContentType: PlacementContentType,
        selectedModelID: PlaceableUSDZModel.ID?,
        entityFactory: CutoutEntityFactory = CutoutEntityFactory(),
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil,
        onPlacementStatusChanged: ((ARPlacementStatus) -> Void)? = nil,
        onStatusChanged: ((ARSessionStatus) -> Void)? = nil
    ) {
        sceneEditor = CutoutSceneEditor(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: selectedAnimalArchetype,
            selectedSpawnMode: selectedSpawnMode,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            entityFactory: entityFactory,
            onSelectionChanged: onSelectionChanged
        )
        self.onSelectionChanged = onSelectionChanged
        self.onPlacementStatusChanged = onPlacementStatusChanged
        self.onStatusChanged = onStatusChanged
        super.init()
        sceneEditor.onSelectionChanged = onSelectionChanged
        sceneEditor.onPlacementResult = { [weak self] result in
            self?.handlePlacementResult(result)
        }
    }

    func runSession(on arView: ARView) {
        statusResetWorkItem?.cancel()
        statusResetWorkItem = nil
        detectedPlaneIDs.removeAll()

        guard ARWorldTrackingConfiguration.isSupported else {
            publishStatus(.unsupported)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            publishStatus(.cameraDenied)
            return
        case .authorized, .notDetermined:
            break
        @unknown default:
            publishStatus(.cameraDenied)
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.delegate = self
        configureSceneOcclusion(on: arView, with: configuration)
        sceneEditor.detachInteraction(clearSelection: false)
        publishStatus(.searching)
        arView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
        arView.renderOptions.insert(.disableGroundingShadows)
        arView.renderOptions.insert(.disableDepthOfField)
        sceneEditor.attachInteraction(
            to: arView,
            surfaceProjector: ARSurfaceProjector()
        ) { [weak self, weak arView] point in
            guard let self, let arView else {
                return
            }
            self.handleEmptyTap(at: point, in: arView)
        }
        startAnimationLoop(in: arView)
        updateStatus(.searching)
    }

    func retrySession(on arView: ARView) {
        publishStatus(.retrying)
        stopAnimationLoop()
        arView.session.pause()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak arView] in
            guard let self, let arView else { return }
            self.runSession(on: arView)
        }
    }

    private func publishStatus(_ status: ARSessionStatus) {
        guard sessionStatus != status else { return }
        sessionStatus = status
        onStatusChanged?(status)
    }

    private func updateSurfaceStatus() {
        publishStatus(detectedPlaneIDs.isEmpty ? .searching : .ready)
    }

    private func reportNoSurface() {
        publishStatus(.noSurface)
        updateStatus(.failed("No surface found. Try pointing at a floor, table, or wall."))
        statusResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.sessionStatus.isBlockingOverlay else { return }
            self.updateSurfaceStatus()
            self.updateStatus(.searching)
        }
        statusResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let nsError = error as NSError
        let cameraUnauthorized = nsError.domain == ARErrorDomain && nsError.code == 103
        if cameraStatus == .denied || cameraStatus == .restricted || cameraUnauthorized {
            publishStatus(.cameraDenied)
        } else {
            publishStatus(.failed)
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planeIDs = anchors.compactMap { anchor in
            anchor is ARPlaneAnchor ? anchor.identifier : nil
        }
        if !planeIDs.isEmpty {
            detectedPlaneIDs.formUnion(planeIDs)
            updateSurfaceStatus()
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let planeIDs = anchors.compactMap { anchor in
            anchor is ARPlaneAnchor ? anchor.identifier : nil
        }
        if !planeIDs.isEmpty {
            detectedPlaneIDs.formUnion(planeIDs)
            updateSurfaceStatus()
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let planeIDs = anchors.compactMap { anchor in
            anchor is ARPlaneAnchor ? anchor.identifier : nil
        }
        if !planeIDs.isEmpty {
            detectedPlaneIDs.subtract(planeIDs)
            updateSurfaceStatus()
        }
    }

    private func configureSceneOcclusion(
        on arView: ARView,
        with configuration: ARWorldTrackingConfiguration
    ) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
    }

    private func handleEmptyTap(at location: CGPoint, in arView: ARView) {
        if selectedContentType == .doodle && selectedSpawnMode == .cameraRoam {
            placeRoamingCutout(in: arView)
            return
        }

        let existingPlaneResult = raycast(
            from: location,
            in: arView,
            allowing: .existingPlaneGeometry
        )
        let estimatedPlaneResult = existingPlaneResult ?? raycast(
            from: location,
            in: arView,
            allowing: .estimatedPlane
        )

        guard let result = estimatedPlaneResult else {
            reportNoSurface()
            return
        }

        let placed = sceneEditor.placeOnPlane(
            at: result.worldTransform.translation,
            normal: simd_normalize([
                result.worldTransform.columns.1.x,
                result.worldTransform.columns.1.y,
                result.worldTransform.columns.1.z
            ]),
            cameraTransform: arView.session.currentFrame?.camera.transform
        )
        handlePlacementResult(placed)
    }

    private func raycast(
        from location: CGPoint,
        in arView: ARView,
        allowing target: ARRaycastQuery.Target
    ) -> ARRaycastResult? {
        arView.raycast(
            from: location,
            allowing: target,
            alignment: .any
        )
        .first
    }

    private func placeRoamingCutout(in arView: ARView) {
        guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
            return
        }
        handlePlacementResult(sceneEditor.placeRoaming(cameraTransform: cameraTransform))
    }

    private func handlePlacementResult(_ result: CutoutPlacementResult) {
        switch result {
        case .placed: updateStatus(.placed)
        case .loading(let message): updateStatus(.loading(message))
        case .limitReached(let maximum):
            updateStatus(.failed("Scene full (\(maximum) objects). Delete one to place another."))
        case .missingAsset: updateStatus(.failed("Choose a doodle before placing it."))
        case .missingModel: updateStatus(.failed("Choose a 3D model before placing it."))
        case .creationFailed(let message): updateStatus(.failed(message))
        }
    }

    private func startAnimationLoop(in arView: ARView) {
        guard displayLink == nil else {
            return
        }

        let displayLink = CADisplayLink(target: self, selector: #selector(handleAnimationFrame(_:)))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func stopAnimationLoop() {
        statusResetWorkItem?.cancel()
        statusResetWorkItem = nil
        sceneEditor.detachInteraction()
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil
    }

    @objc private func handleAnimationFrame(_ displayLink: CADisplayLink) {
        let previousTimestamp = lastFrameTimestamp ?? displayLink.timestamp
        let deltaTime = min(Float(displayLink.timestamp - previousTimestamp), 1 / 20)
        lastFrameTimestamp = displayLink.timestamp
        updatePlacedObjects(deltaTime: deltaTime)
    }

    private func updatePlacedObjects(deltaTime: Float) {
        sceneEditor.update(deltaTime: deltaTime)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            updateStatus(.ready)
            updateSurfaceStatus()
        case .limited(let reason):
            updateStatus(.limited(reason.message))
            if detectedPlaneIDs.isEmpty {
                publishStatus(.searching)
            }
        case .notAvailable:
            updateStatus(.limited("Camera tracking is unavailable."))
            publishStatus(.failed)
        @unknown default:
            updateStatus(.limited("Camera tracking is unavailable."))
            publishStatus(.failed)
        }
    }

    private func updateStatus(_ status: ARPlacementStatus) {
        placementStatus = status
        onPlacementStatusChanged?(status)
    }

    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype) {
        sceneEditor.setSelectedObjectAnimalArchetype(archetype)
    }

    var placedObjectSelection: PlacedObjectSelection? {
        sceneEditor.placedObjectSelection
    }

    func deleteSelectedObject() {
        sceneEditor.deleteSelectedObject()
    }
}

private extension ARCamera.TrackingState.Reason {
    var message: String {
        switch self {
        case .initializing: return "Move your phone slowly to scan the floor or a table."
        case .excessiveMotion: return "Move more slowly to improve tracking."
        case .insufficientFeatures: return "Move to a brighter area with more visible texture."
        case .relocalizing: return "Reacquiring the scene…"
        @unknown default: return "Tracking is limited. Move the phone slowly."
        }
    }
}
