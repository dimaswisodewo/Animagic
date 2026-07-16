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

final class ARSceneController: NSObject, SceneEditing, ARSessionDelegate {
    var cutoutAssets: [CutoutAsset]
    var selectedCutoutID: CutoutAsset.ID?
    var selectedAnimalArchetype: AnimalArchetype
    var selectedSpawnMode: SpawnMode
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private let entityFactory: CutoutEntityFactory
    private let registry: SceneObjectRegistry
    private let interactionManager: ObjectInteractionManager
    private var interactionAdapter: ARViewInteractionAdapter?
    private var detectedPlaneIDs: Set<UUID> = []
    private var statusResetWorkItem: DispatchWorkItem?
    var handledDeleteRequestID: UUID?
    var handledRetryRequestID: UUID?

    private(set) var sessionStatus: ARSessionStatus = .searching

    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)? {
        didSet {
            interactionManager.onSelectionChanged = onSelectionChanged
        }
    }

    var onStatusChanged: ((ARSessionStatus) -> Void)?

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedSpawnMode: SpawnMode,
        entityFactory: CutoutEntityFactory = CutoutEntityFactory(),
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil,
        onStatusChanged: ((ARSessionStatus) -> Void)? = nil
    ) {
        let registry = SceneObjectRegistry()
        self.cutoutAssets = cutoutAssets
        self.selectedCutoutID = selectedCutoutID
        self.selectedAnimalArchetype = selectedAnimalArchetype
        self.selectedSpawnMode = selectedSpawnMode
        self.entityFactory = entityFactory
        self.registry = registry
        interactionManager = ObjectInteractionManager(registry: registry)
        self.onSelectionChanged = onSelectionChanged
        self.onStatusChanged = onStatusChanged
        super.init()
        interactionManager.onSelectionChanged = onSelectionChanged
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

        interactionAdapter?.detach()
        interactionAdapter = nil
        arView.session.delegate = self

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configureSceneOcclusion(on: arView, with: configuration)
        publishStatus(.searching)
        arView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
        arView.renderOptions.insert(.disableGroundingShadows)
        arView.renderOptions.insert(.disableDepthOfField)
        let adapter = ARViewInteractionAdapter(
            manager: interactionManager,
            surfaceProjector: ARSurfaceProjector()
        ) { [weak self, weak arView] point in
            guard let self, let arView else {
                return
            }
            self.handleEmptyTap(at: point, in: arView)
        }
        adapter.attach(to: arView)
        interactionAdapter = adapter
        startAnimationLoop(in: arView)
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
        let callback = onStatusChanged
        if Thread.isMainThread {
            callback?(status)
        } else {
            DispatchQueue.main.async {
                callback?(status)
            }
        }
    }

    private func updateSurfaceStatus() {
        publishStatus(detectedPlaneIDs.isEmpty ? .searching : .ready)
    }

    private func reportNoSurface() {
        publishStatus(.noSurface)
        statusResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.sessionStatus.isBlockingOverlay else { return }
            self.updateSurfaceStatus()
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

    func session(_ session: ARSession, cameraDidChangeTrackingState cameraTrackingState: ARCamera.TrackingState) {
        switch cameraTrackingState {
        case .normal:
            updateSurfaceStatus()
        case .limited:
            if detectedPlaneIDs.isEmpty {
                publishStatus(.searching)
            }
        case .notAvailable:
            publishStatus(.failed)
        @unknown default:
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
        if selectedSpawnMode == .cameraRoam {
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

        placeCutout(in: arView, at: result.worldTransform)
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

    private func placeCutout(in arView: ARView, at transform: simd_float4x4) {
        let objectID = UUID()
        guard let cutoutAsset = selectedCutoutAsset,
              let cutout = try? entityFactory.makeEntity(
                  from: cutoutAsset,
                  archetype: selectedAnimalArchetype,
                  objectID: objectID
              ) else {
            return
        }

        // Keep the motion stage world-up even when the raycast hits a rotated
        // or vertical surface. The detected normal is retained for interaction.
        var stageTransform = matrix_identity_float4x4
        stageTransform.columns.3 = transform.columns.3
        let anchor = AnchorEntity(world: stageTransform)
        anchor.addChild(cutout.root)
        arView.scene.addAnchor(anchor)
        let cameraTransform = arView.session.currentFrame?.camera.transform
        let spawnOrientation = makeSpawnOrientation(
            cameraTransform: cameraTransform,
            anchorTransform: stageTransform
        )
        registry.register(
            PlacedCutout(
                id: objectID,
                anchor: anchor,
                parts: cutout,
                archetype: selectedAnimalArchetype,
                spawnMode: .plane,
                initialYaw: spawnOrientation.yaw,
                initialRoll: spawnOrientation.roll,
                supportSurfaceNormal: simd_normalize([
                    transform.columns.1.x,
                    transform.columns.1.y,
                    transform.columns.1.z
                ])
            )
        )
    }

    private func placeRoamingCutout(in arView: ARView) {
        let objectID = UUID()
        guard let cutoutAsset = selectedCutoutAsset,
              let cutout = try? entityFactory.makeEntity(
                  from: cutoutAsset,
                  archetype: selectedAnimalArchetype,
                  objectID: objectID
              ),
              let cameraTransform = arView.session.currentFrame?.camera.transform else {
            return
        }

        var spawnTransform = matrix_identity_float4x4
        let forward = -cameraTransform.forward
        let right = cameraTransform.right
        let up = cameraTransform.up
        let spawnPosition = cameraTransform.translation
            + (forward * 1.05)
            + (right * Float.random(in: -0.28...0.28))
            + (up * Float.random(in: -0.08...0.18))
        spawnTransform.columns.3 = [spawnPosition.x, spawnPosition.y, spawnPosition.z, 1]

        let anchor = AnchorEntity(world: spawnTransform)
        anchor.addChild(cutout.root)
        arView.scene.addAnchor(anchor)
        let spawnOrientation = makeSpawnOrientation(
            cameraTransform: cameraTransform,
            anchorTransform: spawnTransform
        )
        registry.register(
            PlacedCutout(
                id: objectID,
                anchor: anchor,
                parts: cutout,
                archetype: selectedAnimalArchetype,
                spawnMode: .cameraRoam,
                initialYaw: spawnOrientation.yaw,
                initialRoll: spawnOrientation.roll,
                supportSurfaceNormal: [0, 1, 0]
            )
        )
    }

    private var selectedCutoutAsset: CutoutAsset? {
        if let selectedCutoutID,
           let selectedAsset = cutoutAssets.first(where: { $0.id == selectedCutoutID }) {
            return selectedAsset
        }

        return cutoutAssets.first
    }

    private func makeSpawnOrientation(
        cameraTransform: simd_float4x4?,
        anchorTransform: simd_float4x4
    ) -> (yaw: Float, roll: Float) {
        let cameraFacingYaw: Float
        if let cameraTransform {
            let worldDirection = cameraTransform.translation - anchorTransform.translation
            let localDirection = anchorTransform.inverse * SIMD4<Float>(worldDirection, 0)
            cameraFacingYaw = atan2(localDirection.x, localDirection.z)
        } else {
            cameraFacingYaw = 0
        }
        return (
            yaw: cameraFacingYaw + Float.random(in: (-.pi / 30)...(.pi / 30)),
            roll: Float.random(in: (-.pi / 45)...(.pi / 45))
        )
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
        interactionAdapter?.detach()
        interactionAdapter = nil
        interactionManager.clearSelection()
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
        guard !registry.isEmpty else { return }
        registry.forEach { $0.update(deltaTime: deltaTime) }
    }

    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype) {
        interactionManager.setSelectedAnimalArchetype(archetype)
    }

    var placedObjectSelection: PlacedObjectSelection? {
        interactionManager.selection
    }

    func deleteSelectedObject() {
        interactionManager.deleteSelected()
    }
}
