//
//  NewARPlacementView.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 17/07/26.
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

// MARK: - SwiftUI View
struct NewARPlacementView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var placementStatus: ARPlacementStatus = .searching
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var deleteRequestID: UUID?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARRealityViewRepresentable(
                cutoutAssets: artworkStore.cutoutLibrary,
                selectedCutoutID: selectedCutoutID ?? artworkStore.cutoutLibrary.first?.id,
                spawnAnimalArchetype: selectedAnimalArchetype,
                selectedObjectAnimalArchetype: placedObjectSelection?.animalArchetype,
                selectedContentType: selectedContentType,
                selectedModelID: selectedModelID,
                placedObjectSelection: $placedObjectSelection,
                placementStatus: $placementStatus,
                deleteRequestID: deleteRequestID
            )
            .ignoresSafeArea()
            
            // HUD Status Banner
            VStack {
                ARInstructionBanner(
                    contentType: selectedContentType,
                    spawnMode: .plane,
                    status: placementStatus
                )
                .padding(.top, 16)
                Spacer()
            }
            
            // Selection Toolbar and Carousel Controls
            VStack(spacing: 12) {
                if let placedObjectSelection {
                    SelectedObjectToolbar(title: placedObjectSelection.title) {
                        deleteRequestID = UUID()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                VStack(spacing: 8) {
                    PlacementContentTypePicker(selection: $selectedContentType)
                        .padding(.top, 6)
                    
                    if selectedContentType == .doodle {
                        if artworkStore.cutoutLibrary.isEmpty {
                            EmptyDoodleLibraryMessage()
                        } else {
                            HStack {
                                CutoutPicker(assets: artworkStore.cutoutLibrary, selection: $selectedCutoutID)
                                
                                Menu {
                                    Picker("Archetype", selection: $selectedAnimalArchetype) {
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .padding(.trailing, 8)
                            }
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
        .onAppear {
            if selectedCutoutID == nil {
                selectedCutoutID = artworkStore.cutoutLibrary.first?.id
            }
        }
        .onChange(of: selectedCutoutID) { _, newID in
            if let asset = artworkStore.cutoutLibrary.first(where: { $0.id == newID }),
               let suggested = AnimalArchetype(doodleLabel: asset.resolvedDoodleLabel ?? "", confidence: 1) {
                selectedAnimalArchetype = suggested
            }
        }
    }
}

// MARK: - UIViewRepresentable
struct ARRealityViewRepresentable: UIViewRepresentable {
    let cutoutAssets: [CutoutAsset]
    let selectedCutoutID: CutoutAsset.ID?
    let spawnAnimalArchetype: AnimalArchetype
    let selectedObjectAnimalArchetype: AnimalArchetype?
    let selectedContentType: PlacementContentType
    let selectedModelID: PlaceableUSDZModel.ID?
    @Binding var placedObjectSelection: PlacedObjectSelection?
    @Binding var placementStatus: ARPlacementStatus
    let deleteRequestID: UUID?
    
    func makeCoordinator() -> NewARSceneController {
        NewARSceneController(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: spawnAnimalArchetype,
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
        context.coordinator.runSession(on: arView)
        return arView
    }
    
    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.cutoutAssets = cutoutAssets
        context.coordinator.selectedCutoutID = selectedCutoutID
        context.coordinator.selectedAnimalArchetype = spawnAnimalArchetype
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
        
        if let selectedObjectAnimalArchetype,
           context.coordinator.placedObjectSelection?.animalArchetype != selectedObjectAnimalArchetype {
            context.coordinator.setSelectedObjectAnimalArchetype(selectedObjectAnimalArchetype)
        }
        
        if let deleteRequestID,
           context.coordinator.handledDeleteRequestID != deleteRequestID {
            context.coordinator.handledDeleteRequestID = deleteRequestID
            context.coordinator.deleteSelectedObject()
        }
    }
    
    static func dismantleUIView(_ arView: ARView, coordinator: NewARSceneController) {
        coordinator.stopAnimationLoop()
        coordinator.cleanupFocusIndicator()
        coordinator.cleanupPlaneAnchors()
        arView.session.pause()
    }
}

// MARK: - Scene Coordinator
@MainActor
final class NewARSceneController: NSObject, SceneEditing, @preconcurrency ARSessionDelegate {
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
    var selectedContentType: PlacementContentType {
        get { sceneEditor.selectedContentType }
        set { sceneEditor.selectedContentType = newValue }
    }
    var selectedModelID: PlaceableUSDZModel.ID? {
        get { sceneEditor.selectedModelID }
        set { sceneEditor.selectedModelID = newValue }
    }
    var selectedSpawnMode: SpawnMode = .plane
    
    private let sceneEditor: CutoutSceneEditor
    private weak var arView: ARView?
    private static var hasRegisteredSystem = false
    
    var handledDeleteRequestID: UUID?
    var onPlacementStatusChanged: ((ARPlacementStatus) -> Void)?
    private(set) var placementStatus: ARPlacementStatus = .searching
    
    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)? {
        didSet {
            sceneEditor.onSelectionChanged = onSelectionChanged
        }
    }
    
    // Custom Plane Tracking Visuals
    private var planeAnchors: [UUID: AnchorEntity] = [:]
    
    // Focus Reticle Components
    private var focusIndicator: Entity?
    private var focusAnchor: AnchorEntity?
    private var isTargetAcquired = false
    private var lastValidTransform: simd_float4x4?
    private var lastValidNormal: SIMD3<Float>?
    
    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedContentType: PlacementContentType,
        selectedModelID: PlaceableUSDZModel.ID?,
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil,
        onPlacementStatusChanged: ((ARPlacementStatus) -> Void)? = nil
    ) {
        self.sceneEditor = CutoutSceneEditor(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: selectedAnimalArchetype,
            selectedSpawnMode: .plane,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID
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
        self.arView = arView
        guard ARWorldTrackingConfiguration.isSupported else {
            updateStatus(.failed("ARWorldTracking is not supported on this device."))
            return
        }
        
        // Register ECS System once
        if !Self.hasRegisteredSystem {
            ARPlacementSystem.registerSystem()
            Self.hasRegisteredSystem = true
        }
        
        // Setup focus indicator reticle
        setupFocusIndicator(in: arView)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.delegate = self
        
        configureSceneOcclusionAndSegmentation(on: arView, with: configuration)
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        arView.renderOptions.insert(.disableGroundingShadows)
        arView.renderOptions.insert(.disableDepthOfField)
        
        sceneEditor.attachInteraction(
            to: arView,
            surfaceProjector: ARSurfaceProjector()
        ) { [weak self] point in
            self?.handleEmptyTap()
        }
        
        updateStatus(.searching)
    }
    
    private func configureSceneOcclusionAndSegmentation(on arView: ARView, with configuration: ARWorldTrackingConfiguration) {
        // 1. Environmental Occlusion via LiDAR
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.debugOptions.insert(.showSceneUnderstanding) // Visualizes LiDAR mesh
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.debugOptions.insert(.showSceneUnderstanding) // Visualizes LiDAR mesh
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
        
        // 2. Human Occlusion (Depth-based and standard segmentation)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        }
    }
    
    // MARK: - Focus Reticle & Scanning
    private func setupFocusIndicator(in arView: ARView) {
        let indicator = PlacementIndicatorFactory.make()
        let anchor = AnchorEntity()
        anchor.addChild(indicator)
        
        // Attach ECS component to register with the system loop
        let component = ARPlacementComponent(arView: arView, controller: self)
        anchor.components.set(component)
        
        arView.scene.addAnchor(anchor)
        
        self.focusIndicator = indicator
        self.focusAnchor = anchor
        indicator.isEnabled = false
    }
    
    func updateFocusIndicator(in arView: ARView, focusAnchor: Entity) {
        guard let focusIndicator = self.focusIndicator else { return }
        
        let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        let results = arView.raycast(from: centerPoint, allowing: .existingPlaneGeometry, alignment: .horizontal)
        let result = results.first ?? arView.raycast(from: centerPoint, allowing: .estimatedPlane, alignment: .horizontal).first
        
        if let result {
            let transform = result.worldTransform
            let normal = simd_normalize(SIMD3<Float>(
                transform.columns.1.x,
                transform.columns.1.y,
                transform.columns.1.z
            ))
            
            focusAnchor.transform = Transform(matrix: transform)
            
            if let cameraTransform = arView.session.currentFrame?.camera.transform {
                let cameraPos = cameraTransform.translation
                let indicatorPos = transform.translation
                let lookDirection = simd_normalize(cameraPos - indicatorPos)
                let yaw = atan2(lookDirection.x, lookDirection.z)
                focusIndicator.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            }
            
            if !isTargetAcquired {
                isTargetAcquired = true
                focusIndicator.isEnabled = true
                updateStatusIfScanning(.ready)
            }
            
            lastValidTransform = transform
            lastValidNormal = normal
        } else {
            if isTargetAcquired {
                isTargetAcquired = false
                focusIndicator.isEnabled = false
                updateStatusIfScanning(.searching)
            }
        }
    }
    
    func cleanupFocusIndicator() {
        if let focusAnchor {
            arView?.scene.removeAnchor(focusAnchor)
        }
        focusAnchor = nil
        focusIndicator = nil
        isTargetAcquired = false
    }
    
    // MARK: - Plane Tracking Visualization
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            let mesh = MeshResource.generatePlane(width: planeAnchor.extent.x, depth: planeAnchor.extent.z)
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor.systemBlue.withAlphaComponent(0.12))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.12))
            
            let planeModel = ModelEntity(mesh: mesh, materials: [material])
            planeModel.position = [planeAnchor.center.x, 0, planeAnchor.center.z]
            
            anchorEntity.addChild(planeModel)
            arView?.scene.addAnchor(anchorEntity)
            planeAnchors[planeAnchor.identifier] = anchorEntity
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            
            if let anchorEntity = planeAnchors[planeAnchor.identifier] {
                anchorEntity.children.removeAll()
                
                let mesh = MeshResource.generatePlane(width: planeAnchor.extent.x, depth: planeAnchor.extent.z)
                var material = UnlitMaterial()
                material.color = .init(tint: UIColor.systemBlue.withAlphaComponent(0.12))
                material.blending = .transparent(opacity: .init(floatLiteral: 0.12))
                
                let planeModel = ModelEntity(mesh: mesh, materials: [material])
                planeModel.position = [planeAnchor.center.x, 0, planeAnchor.center.z]
                anchorEntity.addChild(planeModel)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let anchorEntity = planeAnchors.removeValue(forKey: anchor.identifier) {
                arView?.scene.removeAnchor(anchorEntity)
            }
        }
    }
    
    func cleanupPlaneAnchors() {
        for (_, entity) in planeAnchors {
            arView?.scene.removeAnchor(entity)
        }
        planeAnchors.removeAll()
    }
    
    // MARK: - Placed Objects Interaction
    private func handleEmptyTap() {
        guard isTargetAcquired,
              let targetTransform = lastValidTransform,
              let targetNormal = lastValidNormal else {
            updateStatus(.failed("Find a surface before placing."))
            return
        }
        
        let placed = sceneEditor.placeOnPlane(
            at: targetTransform.translation,
            normal: targetNormal,
            cameraTransform: arView?.session.currentFrame?.camera.transform
        )
        handlePlacementResult(placed)
    }
    
    private func handlePlacementResult(_ result: CutoutPlacementResult) {
        switch result {
        case .placed:
            updateStatus(.placed)
            Task {
                try? await Task.sleep(for: .seconds(2))
                if self.placementStatus == .placed {
                    self.updateStatus(self.isTargetAcquired ? .ready : .searching)
                }
            }
        case .loading(let message): updateStatus(.loading(message))
        case .limitReached(let maximum):
            updateStatus(.failed("Scene full (\(maximum) objects). Delete one to place another."))
        case .missingAsset: updateStatus(.failed("Choose a doodle before placing it."))
        case .missingModel: updateStatus(.failed("Choose a 3D model before placing it."))
        case .creationFailed(let message): updateStatus(.failed(message))
        }
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
    
    func stopAnimationLoop() {
        sceneEditor.detachInteraction()
    }
    
    func updateSimulation(deltaTime: Float) {
        sceneEditor.update(deltaTime: deltaTime)
    }
    
    // MARK: - Status
    private func updateStatus(_ status: ARPlacementStatus) {
        placementStatus = status
        onPlacementStatusChanged?(status)
    }
    
    private func updateStatusIfScanning(_ newStatus: ARPlacementStatus) {
        switch placementStatus {
        case .searching, .ready:
            updateStatus(newStatus)
        default:
            break
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            updateStatus(isTargetAcquired ? .ready : .searching)
        case .limited(let reason):
            updateStatus(.limited(reason.trackingMessage))
        case .notAvailable:
            updateStatus(.limited("Camera tracking is unavailable."))
        }
    }
}

// MARK: - Placement Reticle Factory
struct PlacementIndicatorFactory {
    static func make() -> Entity {
        let indicator = Entity()
        let mesh = MeshResource.generatePlane(width: 0.18, depth: 0.18)
        
        if let cgImage = generateReticleTexture(),
           let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) {
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor.white.withAlphaComponent(0.9), texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.9))
            
            let model = ModelEntity(mesh: mesh, materials: [material])
            model.position = [0, 0.002, 0] // Elevate slightly to prevent z-fighting
            indicator.addChild(model)
        }
        return indicator
    }
    
    private static func generateReticleTexture() -> CGImage? {
        let size = CGSize(width: 512, height: 512)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Neon glow ring
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(24)
        context.strokeEllipse(in: CGRect(x: 48, y: 48, width: 416, height: 416))
        
        // Outer white ring
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(12)
        context.strokeEllipse(in: CGRect(x: 50, y: 50, width: 412, height: 412))
        
        // Tech corners
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.85).cgColor)
        context.setLineWidth(12)
        
        // Top-left
        context.move(to: CGPoint(x: 32, y: 96))
        context.addLine(to: CGPoint(x: 32, y: 32))
        context.addLine(to: CGPoint(x: 96, y: 32))
        context.strokePath()
        
        // Top-right
        context.move(to: CGPoint(x: 480, y: 96))
        context.addLine(to: CGPoint(x: 480, y: 32))
        context.addLine(to: CGPoint(x: 416, y: 32))
        context.strokePath()
        
        // Bottom-left
        context.move(to: CGPoint(x: 32, y: 416))
        context.addLine(to: CGPoint(x: 32, y: 480))
        context.addLine(to: CGPoint(x: 96, y: 480))
        context.strokePath()
        
        // Bottom-right
        context.move(to: CGPoint(x: 480, y: 416))
        context.addLine(to: CGPoint(x: 480, y: 480))
        context.addLine(to: CGPoint(x: 416, y: 480))
        context.strokePath()
        
        // Center dot
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 244, y: 244, width: 24, height: 24))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = image.cgImage else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        return cgImage
    }
}

// MARK: - Tracking Message Helpers
private extension ARCamera.TrackingState.Reason {
    var trackingMessage: String {
        switch self {
        case .initializing: return "Move your phone slowly to scan the floor or a table."
        case .excessiveMotion: return "Move more slowly to improve tracking."
        case .insufficientFeatures: return "Move to a brighter area with more visible texture."
        case .relocalizing: return "Reacquiring the scene…"
        @unknown default: return "Tracking is limited. Move the phone slowly."
        }
    }
}

// MARK: - RealityKit ECS Component
struct ARPlacementComponent: Component {
    weak var arView: ARView?
    weak var controller: NewARSceneController?
}

// MARK: - RealityKit ECS System
class ARPlacementSystem: System {
    private static let query = EntityQuery(where: .has(ARPlacementComponent.self))
    
    required init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        
        context.scene.performQuery(Self.query).forEach { entity in
            guard let comp = entity.components[ARPlacementComponent.self],
                  let arView = comp.arView,
                  let controller = comp.controller else { return }
            
            // 1. Tick the placed object simulations
            controller.updateSimulation(deltaTime: deltaTime)
            
            // 2. Perform camera center raycast and update focus reticle
            controller.updateFocusIndicator(in: arView, focusAnchor: entity)
        }
    }
}
