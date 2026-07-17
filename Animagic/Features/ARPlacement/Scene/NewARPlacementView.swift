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
enum GizmoMode: String, CaseIterable, Identifiable {
    case translate = "Translate"
    case rotate = "Rotate"
    case scale = "Scale"
    
    var id: String { self.rawValue }
    var systemImageName: String {
        switch self {
        case .translate: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate: return "arrow.triangle.2.circlepath"
        case .scale: return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        }
    }
}

struct NewARPlacementView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var placementStatus: ARPlacementStatus = .searching
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var deleteRequestID: UUID?
    @State private var activeGizmoMode = GizmoMode.translate
    
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
                activeGizmoMode: activeGizmoMode,
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
                    SelectedObjectGizmoToolbar(
                        title: placedObjectSelection.title,
                        activeMode: $activeGizmoMode
                    ) {
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

struct SelectedObjectGizmoToolbar: View {
    let title: String
    @Binding var activeMode: GizmoMode
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Mode Picker Capsule
            HStack(spacing: 16) {
                ForEach(GizmoMode.allCases) { mode in
                    Button {
                        activeMode = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.systemImageName)
                            Text(mode.rawValue)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(activeMode == mode ? Color.accentColor : Color.clear)
                        .foregroundStyle(activeMode == mode ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6)
            
            // Object info and action
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.footnote)
                
                Text(title)
                    .font(.caption.bold())
                
                Divider()
                    .frame(height: 14)
                    .background(Color.secondary.opacity(0.3))
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6)
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
    let activeGizmoMode: GizmoMode
    let deleteRequestID: UUID?
    
    func makeCoordinator() -> NewARSceneController {
        let controller = NewARSceneController(
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
        controller.activeGizmoMode = activeGizmoMode
        return controller
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
        
        if context.coordinator.activeGizmoMode != activeGizmoMode {
            context.coordinator.activeGizmoMode = activeGizmoMode
            context.coordinator.updateGizmoModeOpacity()
            context.coordinator.updateInteractionGestures()
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
    var activeGizmoMode: GizmoMode = .translate
    
    private let sceneEditor: CutoutSceneEditor
    private weak var arView: ARView?
    private static var hasRegisteredSystem = false
    
    private var interactionAdapter: NewARViewInteractionAdapter?
    private var lastSelectedObject: (any PlacedSceneObject)?
    
    var selectedObject: (any PlacedSceneObject)? {
        sceneEditor.selectedObject
    }
    
    var handledDeleteRequestID: UUID?
    var onPlacementStatusChanged: ((ARPlacementStatus) -> Void)?
    private(set) var placementStatus: ARPlacementStatus = .searching
    
    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)?
    
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
        sceneEditor.onSelectionChanged = { [weak self] selection in
            guard let self else { return }
            self.updateGizmoState(for: selection)
            self.onSelectionChanged?(selection)
        }
        sceneEditor.onPlacementResult = { [weak self] result in
            self?.handlePlacementResult(result)
        }
    }
    
    func runSession(on arView: ARView) {
        self.arView = arView
        sceneEditor.arView = arView
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
        
        let adapter = NewARViewInteractionAdapter(controller: self)
        adapter.attach(to: arView)
        self.interactionAdapter = adapter
        
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
    func handleTapSelection(on entity: Entity?) -> Bool {
        sceneEditor.handleTap(on: entity)
    }
    
    func handleEmptyTap() {
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
    
    func updateGizmoState(for selection: PlacedObjectSelection?) {
        if let lastSelected = lastSelectedObject {
            lastSelected.interactionRoot.findEntity(named: "object_gizmo")?.removeFromParent()
        }
        
        if selection != nil, let selectedObject = selectedObject {
            let bounds = selectedObject.interactionRoot.visualBounds(relativeTo: selectedObject.interactionRoot)
            let width = max(bounds.extents.x, bounds.extents.z)
            
            let gizmo = GizmoEntityFactory.make(targetRadius: max(width * 0.6, 0.15))
            selectedObject.interactionRoot.addChild(gizmo)
            lastSelectedObject = selectedObject
            updateGizmoScale()
            updateGizmoModeOpacity()
        } else {
            lastSelectedObject = nil
        }
    }
    
    func updateGizmoScale() {
        guard let selectedObject = selectedObject,
              let gizmo = selectedObject.interactionRoot.findEntity(named: "object_gizmo"),
              let cameraTransform = arView?.session.currentFrame?.camera.transform else { return }
        
        let objectPos = selectedObject.interactionRoot.position(relativeTo: nil)
        let cameraPos = cameraTransform.translation
        let dist = simd_distance(objectPos, cameraPos)
        
        let scaleFactor = dist * 0.6
        let objectScale = selectedObject.interactionRoot.scale
        let finalGizmoScale: SIMD3<Float> = [
            scaleFactor / max(objectScale.x, 0.01),
            scaleFactor / max(objectScale.y, 0.01),
            scaleFactor / max(objectScale.z, 0.01)
        ]
        gizmo.scale = finalGizmoScale
        
        let localY = selectedObject.interactionRoot.position.y
        if let heightGuide = gizmo.findEntity(named: "gizmo_height_guide") {
            if localY > 0.01 {
                heightGuide.isEnabled = true
                let uncompensatedY = localY / max(finalGizmoScale.y, 0.01)
                heightGuide.scale = [1, uncompensatedY, 1]
                heightGuide.position = [0, -uncompensatedY / 2.0, 0]
            } else {
                heightGuide.isEnabled = false
            }
        }
    }
    
    func updateGizmoModeOpacity() {
        guard let selectedObject = selectedObject,
              let gizmo = selectedObject.interactionRoot.findEntity(named: "object_gizmo") else { return }
        
        let mode = activeGizmoMode
        for child in gizmo.children {
            let name = child.name
            guard name.hasPrefix("gizmo_") else { continue }
            if name == "gizmo_height_guide" { continue }
            
            let isActive: Bool
            switch mode {
            case .translate:
                isActive = name.contains("translate") || name == "gizmo_center_ball"
            case .rotate:
                isActive = name.contains("rotate")
            case .scale:
                isActive = name.contains("scale") || name == "gizmo_center_ball"
            }
            
            let opacity: Float = isActive ? 1.0 : 0.25
            setChildOpacity(child, opacity: opacity)
        }
    }
    
    private func setChildOpacity(_ entity: Entity, opacity: Float) {
        if let model = entity as? ModelEntity {
            if var mat = model.model?.materials.first as? UnlitMaterial {
                mat.blending = .transparent(opacity: .init(floatLiteral: opacity))
                model.model?.materials = [mat]
            }
        }
        entity.children.forEach { setChildOpacity($0, opacity: opacity) }
    }
    
    func projectSurface(_ point: CGPoint, in arView: ARView) -> SurfaceProjection? {
        let projector = ARSurfaceProjector()
        if let selectedObject = selectedObject {
            return projector.project(point, in: arView, for: selectedObject)
        }
        return nil
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
    
    func updateInteractionGestures() {
        interactionAdapter?.updateGestureStates()
    }
    
    func stopAnimationLoop() {
        interactionAdapter?.detach()
        interactionAdapter = nil
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
            
            // 3. Keep the selected object's gizmo scaled constantly
            controller.updateGizmoScale()
        }
    }
}

// MARK: - Gizmo Entity Factory
struct GizmoEntityFactory {
    static func make(targetRadius: Float) -> Entity {
        let container = Entity()
        container.name = "object_gizmo"
        
        let elevation: Float = 0.02
        
        // Grounding footprint shadow under the gizmo (on the floor)
        var footprintMat = UnlitMaterial()
        footprintMat.color = .init(tint: UIColor.black.withAlphaComponent(0.20))
        footprintMat.blending = .transparent(opacity: .init(floatLiteral: 0.20))
        let footprint = ModelEntity(
            mesh: MeshResource.generatePlane(width: targetRadius * 1.8, depth: targetRadius * 1.8),
            materials: [footprintMat]
        )
        footprint.position = [0, 0.001, 0] // Sit slightly above floor to prevent z-fighting
        container.addChild(footprint)
        
        // --- Center Ball (white sphere for floor pan) ---
        var centerMat = UnlitMaterial()
        centerMat.color = .init(tint: .white)
        let centerBall = ModelEntity(mesh: .generateSphere(radius: 0.022), materials: [centerMat])
        centerBall.name = "gizmo_center_ball"
        centerBall.position = [0, elevation + 0.01, 0]
        centerBall.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.028)], filter: CollisionFilter(group: .interactable, mask: .interactable)))
        centerBall.components.set(InputTargetComponent())
        container.addChild(centerBall)
        
        // --- Translation Arrows ---
        // Green Y Translation Arrow
        let translateY = makeArrow(length: targetRadius * 1.5, radius: 0.004, color: .systemGreen)
        translateY.name = "gizmo_translate_y"
        translateY.position = [0, elevation, 0]
        container.addChild(translateY)
        
        // Red X Translation Arrow
        let translateX = makeArrow(length: targetRadius * 1.5, radius: 0.004, color: .systemRed)
        translateX.name = "gizmo_translate_x"
        translateX.position = [0, elevation, 0]
        translateX.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
        container.addChild(translateX)
        
        // Blue Z Translation Arrow
        let translateZ = makeArrow(length: targetRadius * 1.5, radius: 0.004, color: .systemBlue)
        translateZ.name = "gizmo_translate_z"
        translateZ.position = [0, elevation, 0]
        translateZ.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        container.addChild(translateZ)
        
        // Vertical dashed height guide line (hidden by default)
        var guideMat = UnlitMaterial()
        guideMat.color = .init(tint: UIColor.systemGreen.withAlphaComponent(0.6))
        guideMat.blending = .transparent(opacity: .init(floatLiteral: 0.6))
        let guideCylinder = ModelEntity(mesh: .generateCylinder(height: 1.0, radius: 0.002), materials: [guideMat])
        guideCylinder.name = "gizmo_height_guide"
        guideCylinder.isEnabled = false
        container.addChild(guideCylinder)
        
        // --- Rotation Ring ---
        let ringSize = targetRadius * 2.0
        let ringMesh = MeshResource.generatePlane(width: ringSize, depth: ringSize)
        let ringColor = UIColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0)
        if let cgImage = generateRingTexture(color: ringColor),
           let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) {
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor.white, texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.85))
            let ring = ModelEntity(mesh: ringMesh, materials: [material])
            ring.name = "gizmo_rotate"
            ring.position = [0, elevation, 0]
            ring.components.set(CollisionComponent(shapes: [.generateBox(width: ringSize, height: 0.01, depth: ringSize)], filter: CollisionFilter(group: .interactable, mask: .interactable)))
            ring.components.set(InputTargetComponent())
            container.addChild(ring)
        }
        
        // --- Scale Handles ---
        // Red X Scale Handle
        let scaleX = makeScaleAxis(length: targetRadius * 0.95, color: .systemRed)
        scaleX.name = "gizmo_scale_x"
        scaleX.position = [0, elevation, 0]
        scaleX.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
        container.addChild(scaleX)
        
        // Green Y Scale Handle
        let scaleY = makeScaleAxis(length: targetRadius * 0.95, color: .systemGreen)
        scaleY.name = "gizmo_scale_y"
        scaleY.position = [0, elevation, 0]
        container.addChild(scaleY)
        
        // Blue Z Scale Handle
        let scaleZ = makeScaleAxis(length: targetRadius * 0.95, color: .systemBlue)
        scaleZ.name = "gizmo_scale_z"
        scaleZ.position = [0, elevation, 0]
        scaleZ.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        container.addChild(scaleZ)
        
        return container
    }
    
    private static func makeArrow(length: Float, radius: Float, color: UIColor) -> Entity {
        let handle = Entity()
        
        var mat = UnlitMaterial()
        mat.color = .init(tint: color)
        
        // Stem
        let stemHeight = length * 0.8
        let stem = ModelEntity(mesh: .generateCylinder(height: stemHeight, radius: radius), materials: [mat])
        stem.position = [0, stemHeight / 2, 0]
        handle.addChild(stem)
        
        // Tip (Sphere representing a circular tech pin head)
        let tipRadius = radius * 3.5
        let tip = ModelEntity(mesh: .generateSphere(radius: tipRadius), materials: [mat])
        tip.position = [0, stemHeight + tipRadius / 2, 0]
        handle.addChild(tip)
        
        // Add Collision
        let totalHeight = stemHeight + tipRadius
        handle.components.set(CollisionComponent(shapes: [.generateBox(width: radius * 6, height: totalHeight, depth: radius * 6).offsetBy(translation: [0, totalHeight / 2, 0])], filter: CollisionFilter(group: .interactable, mask: .interactable)))
        handle.components.set(InputTargetComponent())
        
        return handle
    }
    
    private static func makeScaleAxis(length: Float, color: UIColor) -> Entity {
        let handle = Entity()
        
        var mat = UnlitMaterial()
        mat.color = .init(tint: color)
        
        // Line stem
        let stemHeight = length * 0.85
        let stem = ModelEntity(mesh: .generateCylinder(height: stemHeight, radius: 0.003), materials: [mat])
        stem.position = [0, stemHeight / 2, 0]
        handle.addChild(stem)
        
        // Cube tip
        let cubeSize = Float(0.015)
        let tip = ModelEntity(mesh: .generateBox(size: cubeSize), materials: [mat])
        tip.position = [0, stemHeight + cubeSize / 2, 0]
        handle.addChild(tip)
        
        // Add Collision
        let totalHeight = stemHeight + cubeSize
        handle.components.set(CollisionComponent(shapes: [.generateBox(width: cubeSize * 1.5, height: totalHeight, depth: cubeSize * 1.5).offsetBy(translation: [0, totalHeight / 2, 0])], filter: CollisionFilter(group: .interactable, mask: .interactable)))
        handle.components.set(InputTargetComponent())
        
        return handle
    }
    
    private static func generateRingTexture(color: UIColor) -> CGImage? {
        let size = CGSize(width: 512, height: 512)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Circular ring
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(16)
        context.strokeEllipse(in: CGRect(x: 20, y: 20, width: 472, height: 472))
        
        // Tech dashes
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(8)
        context.setLineDash(phase: 0, lengths: [20, 20])
        context.strokeEllipse(in: CGRect(x: 36, y: 36, width: 440, height: 440))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = image.cgImage else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        return cgImage
    }
}

// MARK: - Custom Gesture Interaction Adapter
class NewARViewInteractionAdapter: NSObject, UIGestureRecognizerDelegate {
    private enum ManipulationMode {
        case none
        case translatePlane
        case translateY
        case translateX
        case translateZ
        case rotateGizmo
        case scaleX
        case scaleY
        case scaleZ
    }
    
    private weak var arView: ARView?
    private weak var controller: NewARSceneController?
    private var mode: ManipulationMode = .none
    
    private var initialTouchPoint: CGPoint = .zero
    private var initialPosition: SIMD3<Float> = .zero
    private var initialHeight: Float = 0
    private var initialScale: SIMD3<Float> = .one
    private var initialOrientation: simd_quatf = simd_quatf()
    private var initialProjectedPos: SIMD3<Float>?
    
    private var screenAxisDir: CGPoint = .zero
    private var worldAxisDir: SIMD3<Float> = .zero
    private var pixelsPerMeter: CGFloat = 1.0
    
    private var activeHandleEntity: Entity?
    private var originalHandleScale: SIMD3<Float> = .one
    
    private var tapRecognizer: UITapGestureRecognizer?
    private var panRecognizer: UIPanGestureRecognizer?
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private var recognizers: [UIGestureRecognizer] = []
    
    init(controller: NewARSceneController) {
        self.controller = controller
    }
    
    func attach(to arView: ARView) {
        self.arView = arView
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        
        self.tapRecognizer = tap
        self.panRecognizer = pan
        self.pinchRecognizer = pinch
        
        // Ensure tap does not conflict with pan
        tap.numberOfTouchesRequired = 1
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        tap.require(toFail: pan)
        
        [tap, pan, pinch].forEach {
            $0.delegate = self
            arView.addGestureRecognizer($0)
        }
        recognizers = [tap, pan, pinch]
        updateGestureStates()
    }
    
    func detach() {
        clearHighlight()
        guard let arView = self.arView else { return }
        recognizers.forEach(arView.removeGestureRecognizer)
        recognizers.removeAll()
        self.tapRecognizer = nil
        self.panRecognizer = nil
        self.pinchRecognizer = nil
        self.arView = nil
    }
    
    func updateGestureStates() {
        panRecognizer?.isEnabled = true
        pinchRecognizer?.isEnabled = true
    }
    
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = self.arView, let controller = self.controller else { return }
        let point = recognizer.location(in: arView)
        
        let hit = arView.hitTest(point, query: .nearest, mask: .all).first
        let entity = hit?.entity
        
        if !controller.handleTapSelection(on: entity) {
            controller.handleEmptyTap()
        }
    }
    
    private func cancel(_ recognizer: UIGestureRecognizer) {
        recognizer.isEnabled = false
        recognizer.isEnabled = true
    }

    private func findAncestor(of entity: Entity, named name: String) -> Entity? {
        var current: Entity? = entity
        while let curr = current {
            if curr.name == name { return curr }
            current = curr.parent
        }
        return nil
    }

    private func setupScreenAxisProjection(arView: ARView, objectWorldPos: SIMD3<Float>) {
        let axisEnd = objectWorldPos + worldAxisDir
        guard let screenStart = arView.project(objectWorldPos),
              let screenEnd = arView.project(axisEnd) else { return }
        
        let dx = screenEnd.x - screenStart.x
        let dy = screenEnd.y - screenStart.y
        let len = sqrt(dx * dx + dy * dy)
        
        if len > 0.001 {
            screenAxisDir = CGPoint(x: dx / len, y: dy / len)
            pixelsPerMeter = len
        }
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let arView = self.arView,
              let controller = self.controller,
              let selectedObject = controller.selectedObject else { return }
        
        let point = recognizer.location(in: arView)
        
        switch recognizer.state {
        case .possible:
            break
        case .began:
            initialTouchPoint = point
            initialPosition = selectedObject.interactionRoot.position(relativeTo: nil)
            initialHeight = selectedObject.interactionRoot.position.y
            initialScale = selectedObject.interactionRoot.scale
            initialOrientation = selectedObject.interactionRoot.orientation(relativeTo: nil)
            
            let hits = arView.hitTest(point, query: .nearest, mask: .all)
            var foundInteraction = false
            
            for hit in hits {
                let hitEntity = hit.entity
                if hitEntity.name == "gizmo_center_ball" || findAncestor(of: hitEntity, named: "gizmo_center_ball") != nil {
                    mode = .translatePlane
                    let ball = hitEntity.name == "gizmo_center_ball" ? hitEntity : findAncestor(of: hitEntity, named: "gizmo_center_ball")!
                    highlightHandle(ball)
                    foundInteraction = true
                    break
                } else if let rootHandle = findAncestor(of: hitEntity, named: "gizmo_translate_y") {
                    mode = .translateY
                    worldAxisDir = [0, 1, 0]
                    setupScreenAxisProjection(arView: arView, objectWorldPos: initialPosition)
                    highlightHandle(rootHandle)
                    foundInteraction = true
                    break
                } else if let rootHandle = findAncestor(of: hitEntity, named: "gizmo_translate_x") {
                    mode = .translateX
                    worldAxisDir = [1, 0, 0]
                    setupScreenAxisProjection(arView: arView, objectWorldPos: initialPosition)
                    highlightHandle(rootHandle)
                    foundInteraction = true
                    break
                } else if let rootHandle = findAncestor(of: hitEntity, named: "gizmo_translate_z") {
                    mode = .translateZ
                    worldAxisDir = [0, 0, 1]
                    setupScreenAxisProjection(arView: arView, objectWorldPos: initialPosition)
                    highlightHandle(rootHandle)
                    foundInteraction = true
                    break
                } else if hitEntity.name.contains("gizmo_rotate") {
                    mode = .rotateGizmo
                    highlightHandle(hitEntity)
                    foundInteraction = true
                    break
                } else if let rootHandle = findAncestor(of: hitEntity, named: "gizmo_scale_x") {
                    mode = .scaleX
                    worldAxisDir = [1, 0, 0]
                    setupScreenAxisProjection(arView: arView, objectWorldPos: initialPosition)
                    highlightHandle(rootHandle)
                    foundInteraction = true
                    break
                } else if let rootHandle = findAncestor(of: hitEntity, named: "gizmo_scale_y") {
                    mode = .scaleY
                    worldAxisDir = [0, 1, 0]
                    setupScreenAxisProjection(arView: arView, objectWorldPos: initialPosition)
                    highlightHandle(rootHandle)
                    foundInteraction = true
                    break
                } else if let rootHandle = findAncestor(of: hitEntity, named: "gizmo_scale_z") {
                    mode = .scaleZ
                    worldAxisDir = [0, 0, 1]
                    setupScreenAxisProjection(arView: arView, objectWorldPos: initialPosition)
                    highlightHandle(rootHandle)
                    foundInteraction = true
                    break
                } else if isDescendant(hitEntity, of: selectedObject.interactionRoot) {
                    mode = .translatePlane
                    foundInteraction = true
                    break
                }
            }
            
            if !foundInteraction {
                mode = .none
                cancel(recognizer)
            }
            
        case .changed:
            switch mode {
            case .translatePlane:
                if let projection = controller.projectSurface(point, in: arView) {
                    let currentHeight = selectedObject.interactionRoot.position.y
                    selectedObject.interactionRoot.setPosition(projection.position, relativeTo: nil)
                    selectedObject.interactionRoot.position.y = currentHeight
                    selectedObject.supportSurfaceNormal = projection.normal
                }
                
            case .translateX, .translateZ:
                let drag = CGPoint(x: point.x - initialTouchPoint.x, y: point.y - initialTouchPoint.y)
                let projectedPixels = drag.x * screenAxisDir.x + drag.y * screenAxisDir.y
                let meters = Float(projectedPixels / max(pixelsPerMeter, 0.001))
                let newPos = initialPosition + worldAxisDir * meters
                selectedObject.interactionRoot.setPosition(newPos, relativeTo: nil)
                
            case .translateY:
                let drag = CGPoint(x: point.x - initialTouchPoint.x, y: point.y - initialTouchPoint.y)
                let projectedPixels = drag.x * screenAxisDir.x + drag.y * screenAxisDir.y
                let meters = Float(projectedPixels / max(pixelsPerMeter, 0.001))
                let newHeight = min(max(initialHeight + meters, 0.02), 1.5)
                selectedObject.interactionRoot.position.y = newHeight
                
            case .rotateGizmo:
                if let objectScreenPos = arView.project(initialPosition) {
                    let currentAngle = atan2(point.y - objectScreenPos.y, point.x - objectScreenPos.x)
                    let initialAngle = atan2(initialTouchPoint.y - objectScreenPos.y, initialTouchPoint.x - objectScreenPos.x)
                    let angleDelta = Float(currentAngle - initialAngle)
                    let rotation = simd_quatf(angle: angleDelta, axis: [0, 1, 0])
                    selectedObject.interactionRoot.setOrientation(rotation * initialOrientation, relativeTo: nil)
                }
                
            case .scaleX, .scaleY, .scaleZ:
                guard let objectScreenPos = arView.project(initialPosition) else { break }
                let initialVec = CGPoint(
                    x: initialTouchPoint.x - objectScreenPos.x,
                    y: initialTouchPoint.y - objectScreenPos.y
                )
                let currentVec = CGPoint(
                    x: point.x - objectScreenPos.x,
                    y: point.y - objectScreenPos.y
                )
                let initialProj = abs(initialVec.x * screenAxisDir.x + initialVec.y * screenAxisDir.y)
                let currentProj = abs(currentVec.x * screenAxisDir.x + currentVec.y * screenAxisDir.y)
                let ratio = Float(currentProj / max(initialProj, 10.0))
                
                switch mode {
                case .scaleX:
                    let newX = min(max(initialScale.x * ratio, 0.25), 4.0)
                    selectedObject.interactionRoot.scale = [newX, initialScale.y, initialScale.z]
                case .scaleY:
                    let newY = min(max(initialScale.y * ratio, 0.25), 4.0)
                    selectedObject.interactionRoot.scale = [initialScale.x, newY, initialScale.z]
                case .scaleZ:
                    let newZ = min(max(initialScale.z * ratio, 0.25), 4.0)
                    selectedObject.interactionRoot.scale = [initialScale.x, initialScale.y, newZ]
                default:
                    break
                }
                
            case .none:
                break
            }
            
        case .ended, .cancelled, .failed:
            clearHighlight()
            controller.updateGizmoModeOpacity()
            mode = .none
            initialProjectedPos = nil
            
        @unknown default:
            clearHighlight()
            controller.updateGizmoModeOpacity()
            mode = .none
            initialProjectedPos = nil
        }
    }
    
    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let controller = self.controller,
              let selectedObject = controller.selectedObject else { return }
        
        if recognizer.state == .began {
            initialScale = selectedObject.interactionRoot.scale
        } else if recognizer.state == .changed {
            let factor = Float(recognizer.scale)
            let newScale = SIMD3<Float>(
                min(max(initialScale.x * factor, 0.25), 4.0),
                min(max(initialScale.y * factor, 0.25), 4.0),
                min(max(initialScale.z * factor, 0.25), 4.0)
            )
            selectedObject.interactionRoot.scale = newScale
        }
    }

    
    private func isDescendant(_ entity: Entity, of root: Entity) -> Bool {
        var current: Entity? = entity
        while let curr = current {
            if curr == root { return true }
            current = curr.parent
        }
        return false
    }
    
    private func isDescendant(_ entity: Entity, name: String) -> Bool {
        var current: Entity? = entity
        while let curr = current {
            if curr.name == name { return true }
            current = curr.parent
        }
        return false
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt((p1.x - p2.x)*(p1.x - p2.x) + (p1.y - p2.y)*(p1.y - p2.y))
    }
    
    private func color(forHandleName name: String) -> UIColor {
        let lowercase = name.lowercased()
        if lowercase.contains("_x") {
            return .systemRed
        } else if lowercase.contains("_y") {
            return .systemGreen
        } else if lowercase.contains("_z") {
            return .systemBlue
        } else if lowercase.contains("gizmo_rotate") {
            return UIColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0)
        } else if lowercase.contains("uniform") {
            return .white
        }
        return .white
    }
    
    private func setGizmoHandlesOpacity(activeEntity: Entity, opacity: Float) {
        guard let gizmo = activeEntity.parent else { return }
        for child in gizmo.children {
            if child == activeEntity || child.name == "gizmo_height_guide" || child.name.contains("footprint") {
                continue
            }
            setEntityOpacity(child, opacity: opacity)
        }
    }
    
    private func setEntityOpacity(_ entity: Entity, opacity: Float) {
        if let model = entity as? ModelEntity {
            if var mat = model.model?.materials.first as? UnlitMaterial {
                mat.blending = opacity < 1.0 ? .transparent(opacity: .init(floatLiteral: opacity)) : .opaque
                model.model?.materials = [mat]
            }
        }
        entity.children.forEach { setEntityOpacity($0, opacity: opacity) }
    }
    
    private func highlightHandle(_ entity: Entity) {
        clearHighlight()
        activeHandleEntity = entity
        originalHandleScale = entity.scale
        
        entity.scale = originalHandleScale * 1.3
        setGizmoHandlesOpacity(activeEntity: entity, opacity: 0.2)
    }
    
    private func clearHighlight() {
        guard let entity = activeHandleEntity else { return }
        entity.scale = originalHandleScale
        setGizmoHandlesOpacity(activeEntity: entity, opacity: 1.0)
        activeHandleEntity = nil
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return false // Only allow one gesture at a time
    }
}
