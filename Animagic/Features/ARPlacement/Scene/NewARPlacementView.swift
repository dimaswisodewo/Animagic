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

enum NewARSceneCommand: Equatable {
    case place(UUID)
    case clearSelection(UUID)
    case delete(UUID)
    case undoDelete(UUID)
    case discardUndo(UUID)
}

@MainActor
protocol ARPlacementFeedbackProviding: AnyObject {
    func selectionChanged()
    func dragStarted()
    func placementSucceeded()
    func boundaryReached()
    func warning()
    func error()
}

@MainActor
final class SystemARPlacementFeedback: ARPlacementFeedbackProviding {
    static let shared = SystemARPlacementFeedback()

    private init() {}

    func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func dragStarted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
    }

    func placementSucceeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func boundaryReached() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.65)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

struct NewARPlacementView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var placementStatus: ARPlacementStatus = .searching
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var sceneCommand: NewARSceneCommand?
    @State private var objectCount = 0
    @State private var undoAvailable = false
    @State private var undoDismissTask: Task<Void, Never>?
    @Environment(NavigationRouter.self) private var router
    @State private var isImmersive = false
    @State private var showsImmersiveHint = false
    @State private var immersiveHintTask: Task<Void, Never>?
    @State private var cameraPermissionState: CameraPermissionState = .checking
    @State private var isTopMenuExpanded = false
    @State private var isBackpackExpanded = false

    private enum CameraPermissionState {
        case checking
        case authorized
        case denied
    }

    private let initialCutoutID: CutoutAsset.ID?
    private let maximumObjectCount = 20
    private let feedback: any ARPlacementFeedbackProviding

    init(initialCutoutID: CutoutAsset.ID? = nil) {
        self.initialCutoutID = initialCutoutID
        feedback = SystemARPlacementFeedback.shared
        _selectedCutoutID = State(initialValue: initialCutoutID)
    }

    init(
        initialCutoutID: CutoutAsset.ID? = nil,
        feedback: any ARPlacementFeedbackProviding
    ) {
        self.initialCutoutID = initialCutoutID
        self.feedback = feedback
        _selectedCutoutID = State(initialValue: initialCutoutID)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            switch cameraPermissionState {
            case .checking:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground))
            case .denied:
                cameraDeniedView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground))
            case .authorized:
                arContent
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkCameraPermission()
            }
        }
    }

    @ViewBuilder
    private var arContent: some View {
        ZStack(alignment: .bottom) {
            ARRealityViewRepresentable(
                cutoutAssets: artworkStore.cutoutLibrary,
                selectedCutoutID: selectedCutoutID,
                spawnAnimalArchetype: selectedAnimalArchetype,
                selectedObjectAnimalArchetype: placedObjectSelection?.animalArchetype,
                selectedContentType: selectedContentType,
                selectedModelID: selectedModelID,
                placedObjectSelection: $placedObjectSelection,
                placementStatus: $placementStatus,
                objectCount: $objectCount,
                undoAvailable: $undoAvailable,
                command: sceneCommand,
                isImmersive: isImmersive,
                onExitImmersive: exitImmersive,
                feedback: feedback
            )
            .ignoresSafeArea()

            if !isImmersive {
                controlsOverlay
            }

            if showsImmersiveHint {
                Text("Tap empty space to show controls")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.isStaticText)
                    .transition(.opacity)
            }
            
            ARLoadingOverlayView()
        }
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.32), value: placedObjectSelection)
        .animation(.easeOut(duration: 0.2), value: placementStatus)
        .animation(.easeOut(duration: 0.2), value: undoAvailable)
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            synchronizeInitialSelection()
        }
        .onChange(of: artworkStore.cutoutLibrary.map(\.id)) { _, _ in
            synchronizeInitialSelection()
        }
        .onChange(of: selectedCutoutID) { _, newID in
            guard placedObjectSelection == nil,
                  let asset = artworkStore.cutoutLibrary.first(where: { $0.id == newID }),
                  let suggested = suggestedArchetype(for: asset) else { return }
            selectedAnimalArchetype = suggested
        }
        .onChange(of: undoAvailable) { _, isAvailable in
            undoDismissTask?.cancel()
            guard isAvailable else { return }
            undoDismissTask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                sceneCommand = .discardUndo(UUID())
            }
        }
        .onDisappear {
            undoDismissTask?.cancel()
            immersiveHintTask?.cancel()
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: 12) {
            // Top Row
            HStack(alignment: .top) {
                AnimagicIconButton(
                    icon: "chevron.left",
                    backgroundColor: Color(Color.Palette.n20),
                    iconColor: Color(Color.Palette.n70),
                    innerBorderColor: .black.opacity(0.2),
                    action: { router.popToRoot() }
                )
                
                Spacer()
                
                HStack(spacing: 8) {
                    AnimagicExpandableButtonGroup(
                        isExpanded: $isTopMenuExpanded,
                        mainIconExpanded: "xmark",
                        mainIconCollapsed: "rectangle.3.group.fill",
                        mainColor: AnimagicTheme.orange,
                        items: [
                            ExpandableButtonItem(
                                icon: "questionmark",
                                backgroundColor: .green,
                                innerBorderColor: Color.Palette.g400,
                                action: {
                                    isTopMenuExpanded = false
                                    router.push(.help)
                                }
                            ),
                            ExpandableButtonItem(icon: "eye.fill", backgroundColor: AnimagicTheme.orange, innerBorderColor: Color.Palette.o400, action: { enterImmersive() }),
                            ExpandableButtonItem(icon: "camera.fill", backgroundColor: .blue, innerBorderColor: Color.Palette.b400, action: { /* Camera action */ })
                        ]
                    )
                    
                    AnimagicIconButton(
                        icon: "paintbrush.fill",
                        backgroundColor: .yellow,
                        innerBorderColor: Color.Palette.y400,
                        isSelected: selectedContentType == .doodle,
                        action: { router.push(.canvas) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            
            if shouldShowStatus {
                NewARStatusPill(status: placementStatus)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            Spacer()

            if undoAvailable {
                ARDeleteUndoToast {
                    undoDismissTask?.cancel()
                    sceneCommand = .undoDelete(UUID())
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Bottom Row
            HStack(alignment: .bottom) {
                Group {
                    if let placedObjectSelection {
                        NewAREditCard(
                            selection: placedObjectSelection,
                            animalArchetype: archetypeSelection,
                            onDone: {
                                sceneCommand = .clearSelection(UUID())
                            },
                            onDelete: {
                                sceneCommand = .delete(UUID())
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        AnimagicLabelButton(
                            title: placeButtonTitle,
                            backgroundColor: AnimagicTheme.blue,
                            innerBorderColor: Color.Palette.b400,
                            isDisabled: !canPlace,
                            isDimmed: !canPlace,
                            action: { sceneCommand = .place(UUID()) }
                        )
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 24)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    if isBackpackExpanded {
                        VerticalARObjectShelf(
                            contentType: $selectedContentType,
                            cutoutAssets: artworkStore.cutoutLibrary,
                            selectedCutoutID: $selectedCutoutID,
                            selectedModelID: $selectedModelID,
                            canPlace: canPlace,
                            placeButtonTitle: placeButtonTitle,
                            onCollapse: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isBackpackExpanded = false
                                }
                            },
                            onPlace: { sceneCommand = .place(UUID()) },
                            onSelectionFeedback: feedback.selectionChanged
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        AnimagicSideTabButton(
                            icon: "backpack.fill",
                            backgroundColor: AnimagicTheme.orange,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isBackpackExpanded = true
                                }
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow reaching edges
        .ignoresSafeArea(.all, edges: .trailing) // Ignore trailing safe area to sit flush on right edge
    }

    private func enterImmersive() {
        immersiveHintTask?.cancel()
        isImmersive = true
        showsImmersiveHint = true
        immersiveHintTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showsImmersiveHint = false
        }
    }

    private func exitImmersive() {
        immersiveHintTask?.cancel()
        showsImmersiveHint = false
        isImmersive = false
    }

    private var shouldShowStatus: Bool {
        switch placementStatus {
        case .ready:
            false
        default:
            true
        }
    }

    private var canPlace: Bool {
        guard placedObjectSelection == nil,
              placementStatus == .ready,
              objectCount < maximumObjectCount else { return false }

        switch selectedContentType {
        case .doodle:
            return selectedCutoutID != nil && !artworkStore.cutoutLibrary.isEmpty
        case .model:
            return selectedModelID != nil
        }
    }

    private var placeButtonTitle: String {
        if objectCount >= maximumObjectCount {
            return "Scene Full"
        }
        switch placementStatus {
        case .ready:
            return "Place"
        case .loading:
            return "Loading…"
        default:
            return "Find a Surface"
        }
    }

    private var archetypeSelection: Binding<AnimalArchetype> {
        Binding(
            get: { placedObjectSelection?.animalArchetype ?? selectedAnimalArchetype },
            set: { archetype in
                guard let selection = placedObjectSelection,
                      selection.animalArchetype != nil else { return }
                placedObjectSelection = PlacedObjectSelection(
                    objectID: selection.objectID,
                    content: .doodle(archetype)
                )
                feedback.selectionChanged()
            }
        )
    }

    private func synchronizeInitialSelection() {
        if artworkStore.cutoutLibrary.isEmpty {
            selectedCutoutID = nil
            selectedContentType = .model
            return
        }

        if let selectedCutoutID,
           artworkStore.cutoutLibrary.contains(where: { $0.id == selectedCutoutID }) {
            return
        }

        let initialAsset = initialCutoutID.flatMap { id in
            artworkStore.cutoutLibrary.first(where: { $0.id == id })
        } ?? artworkStore.cutoutLibrary.first
        selectedCutoutID = initialAsset?.id
        if let suggested = suggestedArchetype(for: initialAsset) {
            selectedAnimalArchetype = suggested
        }
    }

    private func suggestedArchetype(for asset: CutoutAsset?) -> AnimalArchetype? {
        guard let asset, let label = asset.resolvedDoodleLabel else { return nil }
        return AnimalArchetype(
            doodleLabel: label,
            confidence: asset.doodleOverrideLabel == nil ? asset.doodleClassification?.confidence ?? 0 : 1
        )
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionState = .authorized
        case .notDetermined:
            cameraPermissionState = .checking
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraPermissionState = granted ? .authorized : .denied
                }
            }
        case .denied, .restricted:
            cameraPermissionState = .denied
        @unknown default:
            cameraPermissionState = .denied
        }
    }

    private var cameraDeniedView: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color.secondary.opacity(0.12), in: Circle())
                
                VStack(spacing: 8) {
                    Text("Camera Access Required")
                        .font(.title3.weight(.bold))
                    Text("AniMagic needs camera access to place your doodles in AR. Please enable it in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                VStack(spacing: 12) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Back to Canvas") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 15)
            .padding(24)
            .frame(maxWidth: 360)
        }
    }
}

struct ARRealityViewRepresentable: UIViewRepresentable {
    let cutoutAssets: [CutoutAsset]
    let selectedCutoutID: CutoutAsset.ID?
    let spawnAnimalArchetype: AnimalArchetype
    let selectedObjectAnimalArchetype: AnimalArchetype?
    let selectedContentType: PlacementContentType
    let selectedModelID: PlaceableUSDZModel.ID?
    @Binding var placedObjectSelection: PlacedObjectSelection?
    @Binding var placementStatus: ARPlacementStatus
    @Binding var objectCount: Int
    @Binding var undoAvailable: Bool
    let command: NewARSceneCommand?
    let isImmersive: Bool
    let onExitImmersive: () -> Void
    let feedback: any ARPlacementFeedbackProviding

    func makeCoordinator() -> NewARSceneController {
        NewARSceneController(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: spawnAnimalArchetype,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            feedback: feedback,
            onSelectionChanged: updateSelection,
            onPlacementStatusChanged: updateStatus,
            onObjectCountChanged: updateObjectCount,
            onUndoAvailabilityChanged: updateUndoAvailability,
            onExitImmersive: onExitImmersive
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        context.coordinator.runSession(on: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        let controller = context.coordinator
        controller.cutoutAssets = cutoutAssets
        controller.selectedCutoutID = selectedCutoutID
        controller.selectedAnimalArchetype = spawnAnimalArchetype
        controller.selectedContentType = selectedContentType
        controller.selectedModelID = selectedModelID
        controller.onSelectionChanged = updateSelection
        controller.onPlacementStatusChanged = updateStatus
        controller.onObjectCountChanged = updateObjectCount
        controller.onUndoAvailabilityChanged = updateUndoAvailability
        controller.onExitImmersive = onExitImmersive
        controller.setImmersive(isImmersive)

        if let selectedObjectAnimalArchetype,
           controller.placedObjectSelection?.animalArchetype != selectedObjectAnimalArchetype {
            controller.setSelectedObjectAnimalArchetype(selectedObjectAnimalArchetype)
        }

        if let command, controller.handledCommand != command {
            controller.handledCommand = command
            controller.handle(command)
        }
    }

    static func dismantleUIView(_ arView: ARView, coordinator: NewARSceneController) {
        coordinator.stopAnimationLoop()
        coordinator.cleanupFocusIndicator()
        coordinator.cleanupPlaneAnchors()
        arView.session.pause()
    }

    private func updateSelection(_ selection: PlacedObjectSelection?) {
        Task { @MainActor in
            if placedObjectSelection != selection {
                placedObjectSelection = selection
            }
        }
    }

    private func updateStatus(_ status: ARPlacementStatus) {
        Task { @MainActor in
            if placementStatus != status {
                placementStatus = status
            }
        }
    }

    private func updateObjectCount(_ count: Int) {
        Task { @MainActor in
            if objectCount != count {
                objectCount = count
            }
        }
    }

    private func updateUndoAvailability(_ isAvailable: Bool) {
        Task { @MainActor in
            if undoAvailable != isAvailable {
                undoAvailable = isAvailable
            }
        }
    }
}

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

    private let sceneEditor: CutoutSceneEditor
    private let feedback: any ARPlacementFeedbackProviding
    private weak var arView: ARView?
    private static var hasRegisteredSystem = false
    private var interactionAdapter: NewARViewInteractionAdapter?
    private var lastSelectedObject: (any PlacedSceneObject)?
    private var pendingDeletion: DeletedSceneObject?
    private var planeAnchors: [UUID: AnchorEntity] = [:]
    private var focusIndicator: Entity?
    private var focusAnchor: AnchorEntity?
    private var statusResetTask: Task<Void, Never>?
    private var isTargetAcquired = false
    private var lastValidTransform: simd_float4x4?
    private var lastValidNormal: SIMD3<Float>?
    private var hasPlacedObject = false
    private var isImmersive = false

    var handledCommand: NewARSceneCommand?
    var onPlacementStatusChanged: ((ARPlacementStatus) -> Void)?
    var onSelectionChanged: ((PlacedObjectSelection?) -> Void)?
    var onObjectCountChanged: ((Int) -> Void)?
    var onUndoAvailabilityChanged: ((Bool) -> Void)?
    var onExitImmersive: (() -> Void)?
    private(set) var placementStatus: ARPlacementStatus = .searching

    var selectedObject: (any PlacedSceneObject)? { sceneEditor.selectedObject }
    var placedObjectSelection: PlacedObjectSelection? { sceneEditor.placedObjectSelection }
    var isShowingImmersiveUI: Bool { isImmersive }

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedContentType: PlacementContentType,
        selectedModelID: PlaceableUSDZModel.ID?,
        feedback: any ARPlacementFeedbackProviding,
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil,
        onPlacementStatusChanged: ((ARPlacementStatus) -> Void)? = nil,
        onObjectCountChanged: ((Int) -> Void)? = nil,
        onUndoAvailabilityChanged: ((Bool) -> Void)? = nil,
        onExitImmersive: (() -> Void)? = nil
    ) {
        sceneEditor = CutoutSceneEditor(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: selectedAnimalArchetype,
            selectedSpawnMode: .plane,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID
        )
        self.feedback = feedback
        self.onSelectionChanged = onSelectionChanged
        self.onPlacementStatusChanged = onPlacementStatusChanged
        self.onObjectCountChanged = onObjectCountChanged
        self.onUndoAvailabilityChanged = onUndoAvailabilityChanged
        self.onExitImmersive = onExitImmersive
        super.init()

        sceneEditor.onSelectionChanged = { [weak self] selection in
            guard let self else { return }
            self.updateSelectionIndicator(for: selection)
            self.updateFocusVisibility()
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
            updateStatus(.failed("AR is not supported on this device."))
            return
        }

        if !Self.hasRegisteredSystem {
            ARPlacementSystem.registerSystem()
            Self.hasRegisteredSystem = true
        }

        setupFocusIndicator(in: arView)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configureOcclusion(on: arView, with: configuration)
        arView.session.delegate = self
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arView.renderOptions.insert(.disableGroundingShadows)
        arView.renderOptions.insert(.disableDepthOfField)

        let adapter = NewARViewInteractionAdapter(controller: self, feedback: feedback)
        adapter.attach(to: arView)
        interactionAdapter = adapter
        updateStatus(.searching)
        onObjectCountChanged?(0)
    }

    func handle(_ command: NewARSceneCommand) {
        switch command {
        case .place:
            placeAtFocus()
        case .clearSelection:
            clearSelection()
        case .delete:
            pendingDeletion = deleteSelectedObject()
            let hasUndo = pendingDeletion != nil
            if hasUndo { feedback.warning() }
            onUndoAvailabilityChanged?(hasUndo)
            onObjectCountChanged?(sceneEditor.objectCount)
        case .undoDelete:
            guard let pendingDeletion else { return }
            restoreDeletedObject(pendingDeletion)
            self.pendingDeletion = nil
            feedback.selectionChanged()
            onUndoAvailabilityChanged?(false)
            onObjectCountChanged?(sceneEditor.objectCount)
        case .discardUndo:
            pendingDeletion = nil
            onUndoAvailabilityChanged?(false)
        }
    }

    private func configureOcclusion(on arView: ARView, with configuration: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        }
    }

    private func setupFocusIndicator(in arView: ARView) {
        let indicator = PlacementIndicatorFactory.make()
        let anchor = AnchorEntity()
        anchor.addChild(indicator)
        anchor.components.set(ARPlacementComponent(arView: arView, controller: self))
        arView.scene.addAnchor(anchor)
        focusIndicator = indicator
        focusAnchor = anchor
        indicator.isEnabled = false
    }

    func updateFocusIndicator(in arView: ARView, focusAnchor: Entity) {
        guard let focusIndicator else { return }
        let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let result = arView.raycast(
            from: centerPoint,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        ).first ?? arView.raycast(
            from: centerPoint,
            allowing: .estimatedPlane,
            alignment: .horizontal
        ).first

        guard let result else {
            if isTargetAcquired {
                isTargetAcquired = false
                focusIndicator.isEnabled = false
                updateStatusIfScanning(.searching)
            }
            return
        }

        let transform = result.worldTransform
        let normal = simd_normalize(SIMD3<Float>(
            transform.columns.1.x,
            transform.columns.1.y,
            transform.columns.1.z
        ))
        focusAnchor.transform = Transform(matrix: transform)
        if let cameraTransform = arView.session.currentFrame?.camera.transform {
            let lookDirection = simd_normalize(cameraTransform.translation - transform.translation)
            focusIndicator.orientation = simd_quatf(
                angle: atan2(lookDirection.x, lookDirection.z),
                axis: [0, 1, 0]
            )
        }

        lastValidTransform = transform
        lastValidNormal = normal
        if !isTargetAcquired {
            isTargetAcquired = true
            updateStatusIfScanning(.ready)
        }
        updateFocusVisibility()
    }

    private func updateFocusVisibility() {
        focusIndicator?.isEnabled = !isImmersive && isTargetAcquired && placedObjectSelection == nil
    }

    func cleanupFocusIndicator() {
        if let focusAnchor { arView?.scene.removeAnchor(focusAnchor) }
        focusAnchor = nil
        focusIndicator = nil
        isTargetAcquired = false
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard !hasPlacedObject else { return }
        for planeAnchor in anchors.compactMap({ $0 as? ARPlaneAnchor }) {
            let anchorEntity = makePlaneVisualization(for: planeAnchor)
            anchorEntity.isEnabled = !isImmersive
            arView?.scene.addAnchor(anchorEntity)
            planeAnchors[planeAnchor.identifier] = anchorEntity
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard !hasPlacedObject else { return }
        for planeAnchor in anchors.compactMap({ $0 as? ARPlaneAnchor }) {
            guard let anchorEntity = planeAnchors[planeAnchor.identifier] else { continue }
            anchorEntity.children.removeAll()
            addPlaneModel(for: planeAnchor, to: anchorEntity)
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let anchorEntity = planeAnchors.removeValue(forKey: anchor.identifier) {
                arView?.scene.removeAnchor(anchorEntity)
            }
        }
    }

    private func makePlaneVisualization(for planeAnchor: ARPlaneAnchor) -> AnchorEntity {
        let anchorEntity = AnchorEntity(anchor: planeAnchor)
        addPlaneModel(for: planeAnchor, to: anchorEntity)
        return anchorEntity
    }

    private func addPlaneModel(for planeAnchor: ARPlaneAnchor, to anchorEntity: AnchorEntity) {
        let mesh = MeshResource.generatePlane(width: planeAnchor.extent.x, depth: planeAnchor.extent.z)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor.systemYellow.withAlphaComponent(0.09))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.09))
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        planeModel.position = [planeAnchor.center.x, 0, planeAnchor.center.z]
        anchorEntity.addChild(planeModel)
    }

    func setImmersive(_ isImmersive: Bool) {
        guard self.isImmersive != isImmersive else { return }
        self.isImmersive = isImmersive
        updateFocusVisibility()
        planeAnchors.values.forEach { $0.isEnabled = !isImmersive }
    }

    func requestExitImmersive() {
        guard isImmersive else { return }
        Task { @MainActor [weak self] in
            self?.onExitImmersive?()
        }
    }

    func cleanupPlaneAnchors() {
        for anchor in planeAnchors.values { arView?.scene.removeAnchor(anchor) }
        planeAnchors.removeAll()
    }

    private func placeAtFocus() {
        guard placedObjectSelection == nil,
              isTargetAcquired,
              let targetTransform = lastValidTransform,
              let targetNormal = lastValidNormal else {
            updateStatus(.failed("Move the reticle onto a floor or table first."))
            feedback.warning()
            return
        }

        let result = sceneEditor.placeOnPlane(
            at: targetTransform.translation,
            normal: targetNormal,
            cameraTransform: arView?.session.currentFrame?.camera.transform
        )
        handlePlacementResult(result)
    }

    private func handlePlacementResult(_ result: CutoutPlacementResult) {
        switch result {
        case .placed:
            hasPlacedObject = true
            cleanupPlaneAnchors()
            onObjectCountChanged?(sceneEditor.objectCount)
            feedback.placementSucceeded()
            updateStatus(.placed)
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                if self.placementStatus == .placed {
                    self.updateStatus(self.isTargetAcquired ? .ready : .searching)
                }
            }
        case .loading(let message):
            updateStatus(.loading(message))
        case .limitReached(let maximum):
            updateStatus(.failed("Scene full. Delete an object to place more (maximum \(maximum))."))
            feedback.warning()
        case .missingAsset:
            updateStatus(.failed("Choose a doodle first."))
            feedback.error()
        case .missingModel:
            updateStatus(.failed("Choose a 3D model first."))
            feedback.error()
        case .creationFailed(let message):
            updateStatus(.failed(message))
            feedback.error()
        }
    }

    func handleTapSelection(on entity: Entity?) -> Bool {
        let previousID = placedObjectSelection?.objectID
        let handled = sceneEditor.handleTap(on: entity)
        if handled, placedObjectSelection?.objectID != previousID {
            feedback.selectionChanged()
        }
        return handled
    }

    func selectedObjectInteractionRegion(in arView: ARView) -> CGRect? {
        guard let selectedObject else { return nil }
        let bounds = selectedObject.interactionRoot.visualBounds(relativeTo: nil)
        let corners = [
            SIMD3<Float>(bounds.min.x, bounds.min.y, bounds.min.z),
            SIMD3<Float>(bounds.min.x, bounds.min.y, bounds.max.z),
            SIMD3<Float>(bounds.min.x, bounds.max.y, bounds.min.z),
            SIMD3<Float>(bounds.min.x, bounds.max.y, bounds.max.z),
            SIMD3<Float>(bounds.max.x, bounds.min.y, bounds.min.z),
            SIMD3<Float>(bounds.max.x, bounds.min.y, bounds.max.z),
            SIMD3<Float>(bounds.max.x, bounds.max.y, bounds.min.z),
            SIMD3<Float>(bounds.max.x, bounds.max.y, bounds.max.z)
        ]
        let projected = corners.compactMap(arView.project)
        guard let first = projected.first else { return nil }
        let rect = projected.dropFirst().reduce(CGRect(origin: first, size: .zero)) { result, point in
            result.union(CGRect(origin: point, size: .zero))
        }
        let padded = rect.insetBy(dx: -24, dy: -24)
        return CGRect(
            x: padded.midX - max(padded.width, 60) / 2,
            y: padded.midY - max(padded.height, 60) / 2,
            width: max(padded.width, 60),
            height: max(padded.height, 60)
        )
    }

    func dragPlaneTransform() -> simd_float4x4? {
        guard let selectedObject else { return nil }
        let position = selectedObject.interactionRoot.position(relativeTo: nil)
        return simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position, 1)
        )
    }

    func setSelectionIndicatorDragging(_ isDragging: Bool) {
        guard let ring = selectedObject?.interactionRoot.findEntity(named: "selection_ring") else { return }
        var target = ring.transform
        target.scale = SIMD3(repeating: isDragging ? 1.08 : 1)
        ring.components.set(OpacityComponent(opacity: isDragging ? 1 : 0.9))
        if UIAccessibility.isReduceMotionEnabled {
            ring.transform = target
        } else {
            ring.move(
                to: target,
                relativeTo: ring.parent,
                duration: isDragging ? 0.12 : 0.22,
                timingFunction: .easeOut
            )
        }
    }

    private func updateSelectionIndicator(for selection: PlacedObjectSelection?) {
        if let lastSelectedObject {
            lastSelectedObject.interactionRoot.findEntity(named: "selection_ring")?.removeFromParent()
        }

        guard selection != nil, let selectedObject else {
            lastSelectedObject = nil
            return
        }

        let bounds = selectedObject.interactionRoot.visualBounds(relativeTo: selectedObject.interactionRoot)
        let radius = max(max(bounds.extents.x, bounds.extents.z) * 0.65, 0.12)
        let ring = SelectionRingFactory.make(radius: radius)
        selectedObject.interactionRoot.addChild(ring)
        lastSelectedObject = selectedObject

        guard !UIAccessibility.isReduceMotionEnabled else { return }
        ring.scale = [0.84, 0.84, 0.84]
        var target = ring.transform
        target.scale = .one
        ring.move(to: target, relativeTo: selectedObject.interactionRoot, duration: 0.22, timingFunction: .easeOut)
    }

    func setSelectedObjectAnimalArchetype(_ archetype: AnimalArchetype) {
        sceneEditor.setSelectedObjectAnimalArchetype(archetype)
    }

    @discardableResult
    func deleteSelectedObject() -> DeletedSceneObject? {
        sceneEditor.deleteSelectedObject()
    }

    func restoreDeletedObject(_ deletedObject: DeletedSceneObject) {
        sceneEditor.restoreDeletedObject(deletedObject)
    }

    func clearSelection() {
        sceneEditor.clearSelection()
    }

    func stopAnimationLoop() {
        statusResetTask?.cancel()
        statusResetTask = nil
        setSelectionIndicatorDragging(false)
        interactionAdapter?.detach()
        interactionAdapter = nil
        pendingDeletion = nil
    }

    func updateSimulation(deltaTime: Float) {
        sceneEditor.update(deltaTime: deltaTime)
    }

    private func updateStatus(_ status: ARPlacementStatus) {
        placementStatus = status
        onPlacementStatusChanged?(status)
        if isImmersive, case .failed = status {
            requestExitImmersive()
        }
        
        statusResetTask?.cancel()
        if case .failed = status {
            statusResetTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled, let self else { return }
                self.updateStatus(self.isTargetAcquired ? .ready : .searching)
            }
        }
    }

    private func updateStatusIfScanning(_ newStatus: ARPlacementStatus) {
        switch placementStatus {
        case .searching, .ready, .placed:
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
            requestExitImmersive()
        }
    }
}

private extension ARCamera.TrackingState.Reason {
    var trackingMessage: String {
        switch self {
        case .initializing: "Move your device slowly to find a floor or table."
        case .excessiveMotion: "Move more slowly to improve tracking."
        case .insufficientFeatures: "Try a brighter area with more visible detail."
        case .relocalizing: "Finding your scene again…"
        @unknown default: "Move your device slowly to improve tracking."
        }
    }
}

struct PlacementIndicatorFactory {
    static func make() -> Entity {
        let indicator = Entity()
        let mesh = MeshResource.generatePlane(width: 0.18, depth: 0.18)
        guard let textureImage = makeTexture(),
              let texture = try? TextureResource(image: textureImage, options: .init(semantic: .color)) else {
            return indicator
        }

        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.95))
        let model = ModelEntity(mesh: mesh, materials: [material])
        model.position = [0, 0.002, 0]
        indicator.addChild(model)
        return indicator
    }

    private static func makeTexture() -> CGImage? {
        let size = CGSize(width: 256, height: 256)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(10)
        context.strokeEllipse(in: CGRect(x: 26, y: 26, width: 204, height: 204))
        context.setStrokeColor(UIColor.systemYellow.cgColor)
        context.setLineWidth(8)
        context.setLineDash(phase: 0, lengths: [28, 18])
        context.strokeEllipse(in: CGRect(x: 42, y: 42, width: 172, height: 172))
        context.setFillColor(UIColor.systemYellow.cgColor)
        context.fillEllipse(in: CGRect(x: 118, y: 118, width: 20, height: 20))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}

struct SelectionRingFactory {
    static func make(radius: Float) -> Entity {
        let ring = Entity()
        ring.name = "selection_ring"
        let size = radius * 2
        guard let textureImage = makeTexture(),
              let texture = try? TextureResource(image: textureImage, options: .init(semantic: .color)) else {
            return ring
        }

        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.9))
        let model = ModelEntity(
            mesh: .generatePlane(width: size, depth: size),
            materials: [material]
        )
        model.position = [0, 0.003, 0]
        ring.addChild(model)
        return ring
    }

    private static func makeTexture() -> CGImage? {
        let size = CGSize(width: 256, height: 256)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.28).cgColor)
        context.setLineWidth(20)
        context.strokeEllipse(in: CGRect(x: 22, y: 22, width: 212, height: 212))
        context.setStrokeColor(UIColor.systemYellow.cgColor)
        context.setLineWidth(11)
        context.strokeEllipse(in: CGRect(x: 28, y: 28, width: 200, height: 200))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(4)
        context.strokeEllipse(in: CGRect(x: 42, y: 42, width: 172, height: 172))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}

struct ARPlacementComponent: Component {
    weak var arView: ARView?
    weak var controller: NewARSceneController?
}

final class ARPlacementSystem: System {
    private static let query = EntityQuery(where: .has(ARPlacementComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        context.scene.performQuery(Self.query).forEach { entity in
            guard let component = entity.components[ARPlacementComponent.self],
                  let arView = component.arView,
                  let controller = component.controller else { return }
            controller.updateSimulation(deltaTime: deltaTime)
            controller.updateFocusIndicator(in: arView, focusAnchor: entity)
        }
    }
}

@MainActor
final class NewARViewInteractionAdapter: NSObject, UIGestureRecognizerDelegate {
    private enum Manipulation: Hashable {
        case translation
        case scale
        case rotation
    }

    private weak var arView: ARView?
    private weak var controller: NewARSceneController?
    private let feedback: any ARPlacementFeedbackProviding
    private var recognizers: [UIGestureRecognizer] = []
    private var activeManipulations: Set<Manipulation> = []
    private var dragPlaneTransform: simd_float4x4?
    private var initialDragObjectPosition: SIMD3<Float>?
    private var initialDragTouchPosition: SIMD3<Float>?
    private var initialScale: SIMD3<Float> = .one
    private var initialOrientation = simd_quatf()
    private var didReachLowerScaleBound = false
    private var didReachUpperScaleBound = false

    init(controller: NewARSceneController, feedback: any ARPlacementFeedbackProviding) {
        self.controller = controller
        self.feedback = feedback
    }

    func attach(to arView: ARView) {
        self.arView = arView
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = InitialTouchPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        tap.require(toFail: pan)
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        [tap, pan, pinch, rotation].forEach {
            $0.delegate = self
            arView.addGestureRecognizer($0)
        }
        recognizers = [tap, pan, pinch, rotation]
    }

    func detach() {
        guard let arView else { return }
        recognizers.forEach(arView.removeGestureRecognizer)
        recognizers.removeAll()
        activeManipulations.removeAll()
        resetDragState()
        controller?.setSelectionIndicatorDragging(false)
        controller?.selectedObject?.setInteractionPaused(false)
        self.arView = nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView, let controller else { return }
        let point = recognizer.location(in: arView)
        let entity = arView.hitTest(point, query: .nearest, mask: .interactable).first?.entity
        if entity == nil {
            if controller.isShowingImmersiveUI {
                controller.requestExitImmersive()
            } else {
                controller.clearSelection()
            }
        } else {
            _ = controller.handleTapSelection(on: entity)
        }
    }

    @objc private func handlePan(_ recognizer: InitialTouchPanGestureRecognizer) {
        guard let arView, let controller else { return }
        let point = recognizer.location(in: arView)

        switch recognizer.state {
        case .began:
            let initialPoint = recognizer.initialTouchLocation ?? point
            let exactEntity = arView.hitTest(
                initialPoint,
                query: .nearest,
                mask: .interactable
            ).first?.entity
            let accepted: Bool
            if let exactEntity {
                accepted = controller.handleTapSelection(on: exactEntity)
            } else {
                accepted = controller.selectedObjectInteractionRegion(in: arView)?.contains(initialPoint) == true
            }
            guard accepted,
                  let selectedObject = controller.selectedObject,
                  let planeTransform = controller.dragPlaneTransform(),
                  let initialTouchPosition = arView.unproject(
                    initialPoint,
                    ontoPlane: planeTransform,
                    relativeToCamera: false
                  ),
                  let currentTouchPosition = arView.unproject(
                    point,
                    ontoPlane: planeTransform,
                    relativeToCamera: false
                  ) else {
                cancel(recognizer)
                return
            }
            let initialObjectPosition = selectedObject.interactionRoot.position(relativeTo: nil)
            dragPlaneTransform = planeTransform
            initialDragObjectPosition = initialObjectPosition
            initialDragTouchPosition = initialTouchPosition
            let dragDelta = currentTouchPosition - initialTouchPosition
            selectedObject.interactionRoot.setPosition(
                [
                    initialObjectPosition.x + dragDelta.x,
                    initialObjectPosition.y,
                    initialObjectPosition.z + dragDelta.z
                ],
                relativeTo: nil
            )
            begin(.translation)
            controller.setSelectionIndicatorDragging(true)
            feedback.dragStarted()
        case .changed:
            guard activeManipulations.contains(.translation),
                  let selectedObject = controller.selectedObject,
                  let dragPlaneTransform,
                  let initialDragObjectPosition,
                  let initialDragTouchPosition,
                  let currentTouchPosition = arView.unproject(
                    point,
                    ontoPlane: dragPlaneTransform,
                    relativeToCamera: false
                  ) else { return }
            let dragDelta = currentTouchPosition - initialDragTouchPosition
            selectedObject.interactionRoot.setPosition(
                [
                    initialDragObjectPosition.x + dragDelta.x,
                    initialDragObjectPosition.y,
                    initialDragObjectPosition.z + dragDelta.z
                ],
                relativeTo: nil
            )
        case .ended, .cancelled, .failed:
            end(.translation)
            resetDragState()
            controller.setSelectionIndicatorDragging(false)
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let selectedObject = controller?.selectedObject else { return }
        switch recognizer.state {
        case .began:
            initialScale = selectedObject.interactionRoot.scale
            didReachLowerScaleBound = false
            didReachUpperScaleBound = false
            begin(.scale)
        case .changed:
            let rawScale = initialScale.x * Float(recognizer.scale)
            let displayedScale = rubberBandedScale(rawScale)
            selectedObject.interactionRoot.scale = SIMD3(repeating: displayedScale)
            provideBoundaryFeedback(for: rawScale)
        case .ended, .cancelled, .failed:
            let clamped = min(max(selectedObject.interactionRoot.scale.x, 0.25), 4)
            selectedObject.interactionRoot.scale = SIMD3(repeating: clamped)
            end(.scale)
        default:
            break
        }
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let selectedObject = controller?.selectedObject else { return }
        switch recognizer.state {
        case .began:
            initialOrientation = selectedObject.interactionRoot.orientation(relativeTo: nil)
            begin(.rotation)
        case .changed:
            let axis = simd_normalize(selectedObject.supportSurfaceNormal)
            let rotation = simd_quatf(angle: Float(recognizer.rotation), axis: axis)
            selectedObject.interactionRoot.setOrientation(rotation * initialOrientation, relativeTo: nil)
        case .ended, .cancelled, .failed:
            end(.rotation)
        default:
            break
        }
    }

    private func begin(_ manipulation: Manipulation) {
        activeManipulations.insert(manipulation)
        controller?.selectedObject?.setInteractionPaused(true)
    }

    private func end(_ manipulation: Manipulation) {
        activeManipulations.remove(manipulation)
        if activeManipulations.isEmpty {
            controller?.selectedObject?.setInteractionPaused(false)
        }
    }

    private func rubberBandedScale(_ rawScale: Float) -> Float {
        if rawScale < 0.25 {
            return 0.25 - rubberBand(0.25 - rawScale, dimension: 0.75)
        }
        if rawScale > 4 {
            return 4 + rubberBand(rawScale - 4, dimension: 1)
        }
        return rawScale
    }

    private func rubberBand(_ overshoot: Float, dimension: Float) -> Float {
        let constant: Float = 0.28
        return (overshoot * dimension * constant) / (dimension + constant * overshoot)
    }

    private func provideBoundaryFeedback(for rawScale: Float) {
        if rawScale < 0.25, !didReachLowerScaleBound {
            didReachLowerScaleBound = true
            feedback.boundaryReached()
        } else if rawScale >= 0.25 {
            didReachLowerScaleBound = false
        }
        if rawScale > 4, !didReachUpperScaleBound {
            didReachUpperScaleBound = true
            feedback.boundaryReached()
        } else if rawScale <= 4 {
            didReachUpperScaleBound = false
        }
    }

    private func cancel(_ recognizer: UIGestureRecognizer) {
        recognizer.isEnabled = false
        recognizer.isEnabled = true
    }

    private func resetDragState() {
        dragPlaneTransform = nil
        initialDragObjectPosition = nil
        initialDragTouchPosition = nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let pair = [gestureRecognizer, otherGestureRecognizer]
        return pair.contains(where: { $0 is UIPinchGestureRecognizer })
            && pair.contains(where: { $0 is UIRotationGestureRecognizer })
    }
}

final class InitialTouchPanGestureRecognizer: UIPanGestureRecognizer {
    private(set) var initialTouchLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if initialTouchLocation == nil, let touch = touches.first {
            initialTouchLocation = touch.location(in: view)
        }
        super.touchesBegan(touches, with: event)
    }

    override func reset() {
        super.reset()
        initialTouchLocation = nil
    }
}

struct ARLoadingOverlayView: View {
    @State private var phase = 0
    @State private var textTitleSize: CGFloat = 40
    
    var body: some View {
        ZStack {
            if phase < 3 {
                // Background
                Color.Token.Background.primary
                    .opacity(phase == 0 ? 1.0 : (phase == 1 ? 0.8 : 0.6))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.8), value: phase)
                
                VStack(spacing: 30) {
                    if phase < 2 {
                        iconView(icon: "iphone", secondaryIcon: "hand.tap.fill")
                        outlinedText(text: "Move your phone to start")
                    } else {
                        iconView(icon: "iphone.radiowaves.left.and.right", secondaryIcon: "hand.tap.fill")
                        outlinedText(text: "Finding a Surface")
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.8), value: phase)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    @ViewBuilder
    private func iconView(icon: String, secondaryIcon: String) -> some View {
        ZStack {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(Color(Color.Palette.n70))
            
            Image(systemName: secondaryIcon)
                .font(.system(size: 50))
                .foregroundColor(Color.Token.Button.primary) // orange-ish
                .offset(x: 25, y: 35)
        }
        .frame(height: 120)
    }
    
    @ViewBuilder
    private func outlinedText(text: String) -> some View {
        ZStack {
            ForEach(0..<12) { i in
                Text(text)
                    .font(.custom("Belanosima-SemiBold", size: textTitleSize))
                    .foregroundColor(.white)
                    .offset(
                        x: CGFloat(cos(Double(i) * .pi / 6)) * 6,
                        y: CGFloat(sin(Double(i) * .pi / 6)) * 6
                    )
            }
            Text(text)
                .font(.custom("Belanosima-SemiBold", size: textTitleSize))
                .foregroundColor(Color(Color.Palette.n70))
        }
    }
    
    private func startAnimation() {
        // Phase 0: Solid (0s - 1s)
        // Phase 1: Translucent (1s - 2s)
        // Phase 2: Finding Surface (2s - 3s)
        // Phase 3: Hidden (>3s)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) { phase = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.8)) { phase = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.8)) { phase = 3 }
        }
    }
}
