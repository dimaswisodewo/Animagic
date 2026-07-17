//
//  ARSceneController.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import ARKit
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
    var hoverTargetPosition: SIMD3<Float>? {
        get { sceneEditor.hoverTargetPosition }
        set { sceneEditor.hoverTargetPosition = newValue }
    }
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private let sceneEditor: CutoutSceneEditor
    var handledDeleteRequestID: UUID?
    var onPlacementStatusChanged: ((ARPlacementStatus) -> Void)?
    private(set) var placementStatus: ARPlacementStatus = .searching

    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)? {
        didSet {
            sceneEditor.onSelectionChanged = onSelectionChanged
        }
    }
    
    var isInteractionMode: Bool = false {
        didSet {
            penPanGesture?.isEnabled = isInteractionMode
        }
    }
    var onInteractionModeChanged: ((Bool) -> Void)?
    private weak var penPanGesture: UILongPressGestureRecognizer?

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
        onInteractionModeChanged: ((Bool) -> Void)? = nil
    ) {
        self.onInteractionModeChanged = onInteractionModeChanged
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
        super.init()
        sceneEditor.onSelectionChanged = onSelectionChanged
        sceneEditor.onPlacementResult = { [weak self] result in
            self?.handlePlacementResult(result)
        }
    }

    func runSession(on arView: ARView) {
        guard ARWorldTrackingConfiguration.isSupported else {
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.delegate = self
        configureSceneOcclusion(on: arView, with: configuration)
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
            guard let self, let arView else { return }
            guard !self.isInteractionMode else { return }
            self.handleEmptyTap(at: point, in: arView)
        }
        
        let penPanGesture = UILongPressGestureRecognizer(target: self, action: #selector(handlePenPan(_:)))
        penPanGesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        penPanGesture.minimumPressDuration = 0
        penPanGesture.isEnabled = isInteractionMode
        arView.addGestureRecognizer(penPanGesture)
        self.penPanGesture = penPanGesture
        
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        arView.addInteraction(pencilInteraction)
        
        startAnimationLoop(in: arView)
        updateStatus(.searching)
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
            updateStatus(.failed("No horizontal surface found. Try moving to a clearer area."))
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
            alignment: .horizontal
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
        case .normal: updateStatus(.ready)
        case .limited(let reason): updateStatus(.limited(reason.message))
        case .notAvailable: updateStatus(.limited("Camera tracking is unavailable."))
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
    
    @objc private func handlePenPan(_ recognizer: UILongPressGestureRecognizer) {
        guard isInteractionMode, let arView = recognizer.view as? ARView else { return }
        
        if recognizer.state == .ended || recognizer.state == .cancelled {
            hoverTargetPosition = nil
            return
        }
        
        if recognizer.state == .began {
            sceneEditor.triggerLoveAnimation()
        }
        
        let location = recognizer.location(in: arView)
        
        if let result = raycast(from: location, in: arView, allowing: .estimatedPlane) ??
                        raycast(from: location, in: arView, allowing: .existingPlaneGeometry) {
            hoverTargetPosition = result.worldTransform.translation
        }
    }
}

// MARK: - UIPencilInteractionDelegate

extension ARSceneController: UIPencilInteractionDelegate {
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard squeeze.phase == .ended else { return }
        onInteractionModeChanged?(!isInteractionMode)
    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        // Fallback or secondary tap handling can go here if needed.
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
