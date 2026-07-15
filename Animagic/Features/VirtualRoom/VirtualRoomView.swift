//
//  VirtualRoomView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Combine
import CoreMotion
import RealityKit
import SwiftUI
import UIKit

struct VirtualRoomView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @State private var calibrationRequest = 0
    @State private var interactionMode = VirtualRoomInteractionMode.explore
    @State private var selectedSkybox = VirtualRoomSkybox.citrusOrchard
    @State private var skyboxLoadState = SkyboxLoadState.loading
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedAnimalArchetype = AnimalArchetype.fish
    @State private var selectedSpawnMode = SpawnMode.plane
    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var deleteRequestID: UUID?
    @State private var placementMessage: String?

    var body: some View {
        ZStack {
            RealityRoomView(
                calibrationRequest: calibrationRequest,
                interactionMode: interactionMode,
                selectedSkybox: selectedSkybox,
                cutoutAssets: artworkStore.cutoutLibrary,
                selectedCutoutID: selectedCutoutID,
                spawnAnimalArchetype: selectedAnimalArchetype,
                selectedObjectAnimalArchetype: placedObjectSelection?.animalArchetype,
                selectedSpawnMode: selectedSpawnMode,
                selectedContentType: selectedContentType,
                selectedModelID: selectedModelID,
                placedObjectSelection: $placedObjectSelection,
                skyboxLoadState: $skyboxLoadState,
                placementMessage: $placementMessage,
                deleteRequestID: deleteRequestID
            )
                .ignoresSafeArea()

            CinematicOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Picker("Interaction mode", selection: $interactionMode) {
                        ForEach(VirtualRoomInteractionMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImageName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)

                    Spacer()

                    skyboxMenu
                    calibrationButton
                }

                if let skyboxErrorMessage {
                    Text(skyboxErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.82))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Spacer()

                if interactionMode == .edit {
                    editControls
                }
            }
            .padding()
        }
        .onAppear {
            synchronizeCutoutSelection()
        }
        .onChange(of: artworkStore.cutoutLibrary.map(\.id)) { _, _ in
            synchronizeCutoutSelection()
        }
        .onChange(of: selectedCutoutID) { _, selectedID in
            guard placedObjectSelection == nil,
                  let suggested = suggestedArchetype(
                      for: artworkStore.cutoutLibrary.first(where: { $0.id == selectedID })
                  ) else {
                return
            }
            selectedAnimalArchetype = suggested
        }
        .onChange(of: selectedCutoutAsset?.resolvedDoodleLabel) { _, _ in
            guard placedObjectSelection == nil,
                  let suggested = suggestedArchetype(for: selectedCutoutAsset) else {
                return
            }
            selectedAnimalArchetype = suggested
        }
        .navigationTitle("Virtual Room")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calibrationButton: some View {
        Button {
            calibrationRequest += 1
        } label: {
            Image(systemName: "scope")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Calibrate")
    }

    private var skyboxErrorMessage: String? {
        if case .failed(let message) = skyboxLoadState {
            return message
        }
        return nil
    }

    private var skyboxMenu: some View {
        Menu {
            Picker("Skybox", selection: $selectedSkybox) {
                ForEach(VirtualRoomSkybox.allCases) { skybox in
                    Text(skybox.title).tag(skybox)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if skyboxLoadState == .loading {
                    ProgressView()
                } else {
                    Image(systemName: skyboxLoadState.isFailure ? "exclamationmark.triangle" : "globe")
                }
                Text(selectedSkybox.title)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Choose skybox")
    }

    @ViewBuilder
    private var editControls: some View {
        VStack(spacing: 12) {
            VirtualRoomInstructionBanner(
                contentType: selectedContentType,
                spawnMode: selectedSpawnMode,
                hasCutouts: !artworkStore.cutoutLibrary.isEmpty,
                placementMessage: placementMessage
            )
            PlacementContentTypePicker(selection: $selectedContentType)
            if selectedContentType == .model {
                USDZModelPicker(selection: $selectedModelID)
            } else {
                SpawnModePicker(selection: $selectedSpawnMode)
                if artworkStore.cutoutLibrary.isEmpty {
                    EmptyDoodleLibraryMessage()
                } else {
                    CutoutPicker(assets: artworkStore.cutoutLibrary, selection: $selectedCutoutID)
                    if let selectedCutoutAsset {
                        DoodleCorrectionMenu(asset: selectedCutoutAsset) { label in
                            artworkStore.updateCutoutOverride(id: selectedCutoutAsset.id, label: label)
                        }
                    }
                    AnimalArchetypePicker(selection: archetypeSelection)
                }
            }
            if let placedObjectSelection {
                SelectedObjectToolbar(title: placedObjectSelection.title) {
                    deleteRequestID = UUID()
                }
            }
        }
    }

    private var selectedCutoutAsset: CutoutAsset? {
        if let selectedCutoutID {
            return artworkStore.cutoutLibrary.first(where: { $0.id == selectedCutoutID })
        }
        return artworkStore.cutoutLibrary.first
    }

    private var archetypeSelection: Binding<AnimalArchetype> {
        Binding(
            get: { placedObjectSelection?.animalArchetype ?? selectedAnimalArchetype },
            set: { archetype in
                if let selection = placedObjectSelection,
                   selection.animalArchetype != nil {
                    placedObjectSelection = PlacedObjectSelection(
                        objectID: selection.objectID,
                        content: .doodle(archetype)
                    )
                } else {
                    selectedAnimalArchetype = archetype
                }
            }
        )
    }

    private func synchronizeCutoutSelection() {
        if let selectedCutoutID,
           artworkStore.cutoutLibrary.contains(where: { $0.id == selectedCutoutID }) {
            return
        }
        selectedCutoutID = artworkStore.cutoutLibrary.first?.id
        if let suggested = suggestedArchetype(for: artworkStore.cutoutLibrary.first) {
            selectedAnimalArchetype = suggested
        }
    }

    private func suggestedArchetype(for asset: CutoutAsset?) -> AnimalArchetype? {
        guard let asset, let label = asset.resolvedDoodleLabel else {
            return nil
        }
        return AnimalArchetype(
            doodleLabel: label,
            confidence: asset.doodleOverrideLabel == nil ? asset.doodleClassification?.confidence ?? 0 : 1
        )
    }
}

enum VirtualRoomInteractionMode: String, CaseIterable, Identifiable {
    case explore
    case edit

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImageName: String { self == .explore ? "figure.walk" : "wand.and.stars" }
}

enum VirtualRoomSkybox: String, CaseIterable, Identifiable {
    case citrusOrchard = "CitrusOrchard"
    case land = "Land"
    case underwater = "Underwater"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .citrusOrchard: "Citrus Orchard"
        case .land: "Land"
        case .underwater: "Underwater"
        }
    }
}

enum SkyboxLoadState: Equatable {
    case loading
    case loaded(VirtualRoomSkybox)
    case failed(String)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

private struct VirtualRoomInstructionBanner: View {
    let contentType: PlacementContentType
    let spawnMode: SpawnMode
    let hasCutouts: Bool
    let placementMessage: String?

    var body: some View {
        VStack(spacing: 6) {
            Label("Edit Room", systemImage: "wand.and.stars")
                .font(.headline)
            Text(placementMessage ?? instruction)
                .font(.subheadline)
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var instruction: String {
        if contentType == .model {
            return "Choose a 3D model, then tap the floor to place it."
        }
        return hasCutouts ? spawnMode.instruction : "Your cutout library is empty."
    }
}

struct CinematicOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.18),
                    Color(red: 0.18, green: 0.11, blue: 0.06).opacity(0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.42)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )

            VStack {
                Rectangle()
                    .fill(.black.opacity(0.12))
                    .frame(height: 34)

                Spacer()

                Rectangle()
                    .fill(.black.opacity(0.12))
                    .frame(height: 34)
            }
        }
    }
}

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
            onPlacementMessageChanged: updatePlacementMessage
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

@MainActor
final class RoomCoordinator: NSObject {
    private enum Constants {
        static let roomSize: Float = 8.0
        static let wallHeight: Float = 3.0
        static let wallThickness: Float = 0.08
        static let floorThickness: Float = 0.05
        static let navigationFloorSize: Float = 16.0
        static let cameraHeight: Float = 1.6
        static let cameraMoveSpeed: Float = 3.5
        static let destinationTolerance: Float = 0.03
        static let motionUpdateInterval = 1.0 / 60.0
        static let movementPaddingFromWall: Float = 0.45
        static let panYawSensitivity: Float = 0.006
        static let moveIndicatorRadius: Float = 0.22
        static let moveIndicatorThickness: Float = 0.012
        static let moveIndicatorHover: Float = 0.008
        static let moveIndicatorSpinSpeed: Float = 1.6
        static let moveIndicatorPulseSpeed: Float = 3.5
        static let motionSmoothingRate: Float = 14.0
        static let ambienceAudioName = "TokyoSpringAmbience.mp3"
        static let ambienceSourceOffset = SIMD3<Float>(0, 1.3, 0)
        static let pickupHoldDistance: Float = 1.25
        static let pickupHoldHeightOffset: Float = -0.18
        static let pickupFollowRate: Float = 14.0
        static let launchSpeed: Float = 6.5
        static let pickupNamePrefix = "pickup_"

        static var halfRoomSize: Float {
            roomSize / 2.0
        }

        static var movementLimit: Float {
            navigationFloorSize / 2.0 - movementPaddingFromWall
        }
    }

    private let motionManager = CMMotionManager()
    private let motionOrientationStore = MotionOrientationStore()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.diroudough.animagic.virtual-room-motion"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let cameraRig = Entity()
    private let motionRig = Entity()
    private let cameraEntity = Entity()
    private let moveIndicator = Entity()
    private let ambienceEntity = Entity()
    private let cutoutEditor: CutoutSceneEditor

    private weak var arView: ARView?
    private var updateSubscription: (any Cancellable)?
    private var floorEntity: Entity?
    private weak var sceneRoot: AnchorEntity?
    private var destination: SIMD3<Float>?
    private var calibrationQuaternion: simd_quatf?
    private var currentDeviceQuaternion: simd_quatf?
    private var smoothedMotionQuaternion: simd_quatf?
    private var motionInterfaceOrientation: UIInterfaceOrientation?
    private var manualYawOffset: Float = 0
    private var lastHandledCalibrationRequest = 0
    private var moveIndicatorTime: Float = 0
    private var ambiencePlaybackController: AudioPlaybackController?
    private weak var heldEntity: ModelEntity?
    private weak var roomTapGesture: UITapGestureRecognizer?
    private weak var roomPanGesture: UIPanGestureRecognizer?
    private var interactionMode = VirtualRoomInteractionMode.explore
    private var selectedSkybox = VirtualRoomSkybox.citrusOrchard
    private var skyboxTasks: [VirtualRoomSkybox: Task<EnvironmentResource, Error>] = [:]
    private var appliedSkybox: VirtualRoomSkybox?
    private var handledDeleteRequestID: UUID?
    private var onSkyboxLoadStateChanged: ((SkyboxLoadState) -> Void)?
    private var onPlacementMessageChanged: ((String?) -> Void)?

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedSpawnMode: SpawnMode,
        selectedContentType: PlacementContentType,
        selectedModelID: PlaceableUSDZModel.ID?,
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil,
        onSkyboxLoadStateChanged: ((SkyboxLoadState) -> Void)? = nil,
        onPlacementMessageChanged: ((String?) -> Void)? = nil
    ) {
        self.onSkyboxLoadStateChanged = onSkyboxLoadStateChanged
        self.onPlacementMessageChanged = onPlacementMessageChanged
        cutoutEditor = CutoutSceneEditor(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalArchetype: selectedAnimalArchetype,
            selectedSpawnMode: selectedSpawnMode,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            configuration: .virtualRoom,
            onSelectionChanged: onSelectionChanged
        )
        super.init()
        cutoutEditor.onPlacementResult = { [weak self] result in
            self?.handlePlacementResult(result)
        }
    }

    func makeView() -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )

        self.arView = arView
        arView.renderOptions.insert(.disableMotionBlur)
#if DEBUG
        arView.debugOptions.insert(.showStatistics)
#endif
        configureSceneBackground(on: arView)

        buildRoomScene(in: arView)
        installGestures(on: arView)
        startMotionUpdates()
        subscribeToSceneUpdates(in: arView)

        return arView
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        motionQueue.cancelAllOperations()
        ambiencePlaybackController?.stop()
        updateSubscription?.cancel()
        updateSubscription = nil
        cutoutEditor.detachInteraction()
        skyboxTasks.values.forEach { $0.cancel() }
        skyboxTasks.removeAll()
    }

    func handleCalibrationRequest(_ request: Int) {
        guard request != lastHandledCalibrationRequest else {
            return
        }

        lastHandledCalibrationRequest = request
        calibrateCamera()
    }

    func update(
        interactionMode: VirtualRoomInteractionMode,
        skybox: VirtualRoomSkybox,
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalArchetype: AnimalArchetype,
        selectedObjectAnimalArchetype: AnimalArchetype?,
        selectedSpawnMode: SpawnMode,
        selectedContentType: PlacementContentType,
        selectedModelID: PlaceableUSDZModel.ID?,
        deleteRequestID: UUID?,
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)?,
        onSkyboxLoadStateChanged: ((SkyboxLoadState) -> Void)?,
        onPlacementMessageChanged: ((String?) -> Void)?
    ) {
        cutoutEditor.cutoutAssets = cutoutAssets
        cutoutEditor.selectedCutoutID = selectedCutoutID
        cutoutEditor.selectedAnimalArchetype = selectedAnimalArchetype
        cutoutEditor.selectedSpawnMode = selectedSpawnMode
        cutoutEditor.selectedContentType = selectedContentType
        cutoutEditor.selectedModelID = selectedModelID
        cutoutEditor.onSelectionChanged = onSelectionChanged
        self.onSkyboxLoadStateChanged = onSkyboxLoadStateChanged
        self.onPlacementMessageChanged = onPlacementMessageChanged

        if self.interactionMode != interactionMode {
            setInteractionMode(interactionMode)
        }
        if selectedSkybox != skybox || appliedSkybox == nil {
            applySkybox(skybox)
        }
        if let selectedObjectAnimalArchetype,
           cutoutEditor.placedObjectSelection?.animalArchetype != selectedObjectAnimalArchetype {
            cutoutEditor.setSelectedObjectAnimalArchetype(selectedObjectAnimalArchetype)
        }
        if let deleteRequestID,
           handledDeleteRequestID != deleteRequestID {
            handledDeleteRequestID = deleteRequestID
            cutoutEditor.deleteSelectedObject()
            onPlacementMessageChanged?(nil)
        }
    }

    private func configureSceneBackground(on arView: ARView) {
        arView.environment.background = .color(UIColor(red: 0.03, green: 0.035, blue: 0.045, alpha: 1.0))
        VirtualRoomSkybox.allCases.forEach { _ = skyboxTask(for: $0) }
        applySkybox(selectedSkybox)
    }

    private func skyboxTask(
        for skybox: VirtualRoomSkybox
    ) -> Task<EnvironmentResource, Error> {
        if let task = skyboxTasks[skybox] {
            return task
        }
        let task = Task {
            try await EnvironmentResource(named: skybox.rawValue, in: .main)
        }
        skyboxTasks[skybox] = task
        return task
    }

    private func applySkybox(_ skybox: VirtualRoomSkybox) {
        selectedSkybox = skybox
        guard appliedSkybox != skybox else {
            onSkyboxLoadStateChanged?(.loaded(skybox))
            return
        }

        onSkyboxLoadStateChanged?(.loading)
        let task = skyboxTask(for: skybox)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let resource = try await task.value
                guard self.selectedSkybox == skybox else { return }
                self.arView?.environment.background = .skybox(resource)
                self.appliedSkybox = skybox
                self.onSkyboxLoadStateChanged?(.loaded(skybox))
            } catch is CancellationError {
                return
            } catch {
                guard self.selectedSkybox == skybox else { return }
                self.onSkyboxLoadStateChanged?(
                    .failed("Unable to load \(skybox.title).")
                )
            }
        }
    }

    // MARK: - Scene Setup

    private func buildRoomScene(in arView: ARView) {
        let root = AnchorEntity(world: .zero)
        arView.scene.anchors.append(root)
        sceneRoot = root

        addBedroomScene(to: root)
        addNavigationFloor(to: root)
        addPhysicsPlayground(to: root)
        addLights(to: root)
        addCamera(to: root)
        addMoveIndicator(to: root)
    }

    private func addBedroomScene(to root: AnchorEntity) {
        do {
            let statueRoom = try Entity.load(named: "StatueRoom")
            statueRoom.name = "StatueRoom"
            root.addChild(statueRoom)
            installSpatialAmbience(on: statueRoom)
        } catch {
            addRoom(to: root)
            let ambienceTarget = addObjects(to: root)
            installSpatialAmbience(on: ambienceTarget)
        }
    }

    private func addNavigationFloor(to root: AnchorEntity) {
        let floorSize: SIMD3<Float> = [
            Constants.navigationFloorSize,
            Constants.floorThickness,
            Constants.navigationFloorSize
        ]
        let floor = Entity()
        floor.name = "navigationFloor"
        floor.position = [0, -Constants.floorThickness / 2, 0]
        floor.components.set(
            CollisionComponent(shapes: [.generateBox(size: floorSize)])
        )
        floor.components.set(
            PhysicsBodyComponent(
                massProperties: .default,
                material: .generate(staticFriction: 0.9, dynamicFriction: 0.8, restitution: 0.15),
                mode: .static
            )
        )

        root.addChild(floor)
        floorEntity = floor
    }

    private func addRoom(to root: AnchorEntity) {
        let floorMaterial = SimpleMaterial(color: .black, isMetallic: false)
        let wallMaterial = SimpleMaterial(color: UIColor(white: 0.82, alpha: 1), isMetallic: false)

        let floor = makeBox(
            named: "floor",
            size: [Constants.roomSize, Constants.floorThickness, Constants.roomSize],
            position: [0, -Constants.floorThickness / 2, 0],
            material: floorMaterial
        )
        root.addChild(floor)
        floorEntity = floor

        addWall(
            named: "backWall",
            size: [Constants.roomSize, Constants.wallHeight, Constants.wallThickness],
            position: [0, Constants.wallHeight / 2, -Constants.halfRoomSize],
            material: wallMaterial,
            to: root
        )
        addWall(
            named: "frontWall",
            size: [Constants.roomSize, Constants.wallHeight, Constants.wallThickness],
            position: [0, Constants.wallHeight / 2, Constants.halfRoomSize],
            material: wallMaterial,
            to: root
        )
        addWall(
            named: "leftWall",
            size: [Constants.wallThickness, Constants.wallHeight, Constants.roomSize],
            position: [-Constants.halfRoomSize, Constants.wallHeight / 2, 0],
            material: wallMaterial,
            to: root
        )
        addWall(
            named: "rightWall",
            size: [Constants.wallThickness, Constants.wallHeight, Constants.roomSize],
            position: [Constants.halfRoomSize, Constants.wallHeight / 2, 0],
            material: wallMaterial,
            to: root
        )
    }

    private func addWall(
        named name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial,
        to root: AnchorEntity
    ) {
        root.addChild(makeStaticBox(named: name, size: size, position: position, material: material))
    }

    @discardableResult
    private func addObjects(to root: AnchorEntity) -> Entity {
        let red = SimpleMaterial(color: UIColor(red: 0.78, green: 0.12, blue: 0.18, alpha: 1), isMetallic: false)
        let blue = SimpleMaterial(color: UIColor(red: 0.1, green: 0.32, blue: 0.8, alpha: 1), isMetallic: false)
        let green = SimpleMaterial(color: UIColor(red: 0.1, green: 0.55, blue: 0.28, alpha: 1), isMetallic: false)
        let wood = SimpleMaterial(color: UIColor(red: 0.5, green: 0.34, blue: 0.18, alpha: 1), isMetallic: false)

        root.addChild(makeBox(
            named: "redCube",
            size: [0.7, 0.7, 0.7],
            position: [-2.6, 0.35, -2.4],
            material: red
        ))
        root.addChild(makeSphere(
            named: "blueSphere",
            radius: 0.38,
            position: [2.3, 0.38, -2.2],
            material: blue
        ))
        root.addChild(makeCylinder(
            named: "greenCylinder",
            radius: 0.32,
            height: 1.1,
            position: [2.5, 0.55, 1.9],
            material: green
        ))
        addTable(to: root, material: wood)
        return root.findEntity(named: "greenCylinder") ?? root
    }

    private func addTable(to root: AnchorEntity, material: SimpleMaterial) {
        let tableParts: [(name: String, size: SIMD3<Float>, position: SIMD3<Float>)] = [
            ("tableTop", [1.4, 0.16, 0.8], [-1.5, 0.65, 1.7]),
            ("tableLegFrontLeft", [0.14, 0.65, 0.14], [-2.05, 0.32, 1.4]),
            ("tableLegFrontRight", [0.14, 0.65, 0.14], [-0.95, 0.32, 1.4]),
            ("tableLegBackLeft", [0.14, 0.65, 0.14], [-2.05, 0.32, 2.0]),
            ("tableLegBackRight", [0.14, 0.65, 0.14], [-0.95, 0.32, 2.0])
        ]

        for part in tableParts {
            root.addChild(makeStaticBox(
                named: part.name,
                size: part.size,
                position: part.position,
                material: material
            ))
        }
    }

    private func addPhysicsPlayground(to root: AnchorEntity) {
        let warmOrange = SimpleMaterial(color: UIColor(red: 0.93, green: 0.45, blue: 0.17, alpha: 1), isMetallic: false)
        let sand = SimpleMaterial(color: UIColor(red: 0.84, green: 0.74, blue: 0.58, alpha: 1), isMetallic: false)
        let teal = SimpleMaterial(color: UIColor(red: 0.14, green: 0.64, blue: 0.66, alpha: 1), isMetallic: false)
        let slate = SimpleMaterial(color: UIColor(red: 0.27, green: 0.31, blue: 0.38, alpha: 1), isMetallic: false)

        root.addChild(makeStaticBox(
            named: "playgroundBase",
            size: [2.8, 0.12, 2.1],
            position: [0, 0.06, -2.35],
            material: slate
        ))

        let stackPositions: [SIMD3<Float>] = [
            [-0.38, 0.22, -2.35],
            [0, 0.22, -2.35],
            [0.38, 0.22, -2.35],
            [-0.19, 0.62, -2.35],
            [0.19, 0.62, -2.35],
            [0, 1.02, -2.35]
        ]

        for (index, position) in stackPositions.enumerated() {
            root.addChild(makeDynamicBox(
                named: "\(Constants.pickupNamePrefix)crate_\(index)",
                size: [0.34, 0.34, 0.34],
                position: position,
                material: sand,
                mass: 0.9
            ))
        }

        root.addChild(makeDynamicSphere(
            named: "\(Constants.pickupNamePrefix)ball",
            radius: 0.18,
            position: [0.95, 0.42, -1.55],
            material: warmOrange,
            mass: 0.55
        ))
        root.addChild(makeDynamicCylinder(
            named: "\(Constants.pickupNamePrefix)roller",
            radius: 0.15,
            height: 0.48,
            position: [-0.95, 0.34, -1.55],
            material: teal,
            mass: 0.7
        ))
    }

    private func makeBox(
        named name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        configure(entity, name: name, position: position)
        return entity
    }

    private func makeStaticBox(
        named name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let entity = makeBox(named: name, size: size, position: position, material: material)
        configureStaticPhysics(for: entity)
        return entity
    }

    private func makeDynamicBox(
        named name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial,
        mass: Float
    ) -> ModelEntity {
        let entity = makeBox(named: name, size: size, position: position, material: material)
        configureDynamicPhysics(for: entity, mass: mass)
        return entity
    }

    private func makeSphere(
        named name: String,
        radius: Float,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
        configure(entity, name: name, position: position)
        return entity
    }

    private func makeDynamicSphere(
        named name: String,
        radius: Float,
        position: SIMD3<Float>,
        material: SimpleMaterial,
        mass: Float
    ) -> ModelEntity {
        let entity = makeSphere(named: name, radius: radius, position: position, material: material)
        configureDynamicPhysics(for: entity, mass: mass)
        return entity
    }

    private func makeCylinder(
        named name: String,
        radius: Float,
        height: Float,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [material])
        configure(entity, name: name, position: position)
        return entity
    }

    private func makeDynamicCylinder(
        named name: String,
        radius: Float,
        height: Float,
        position: SIMD3<Float>,
        material: SimpleMaterial,
        mass: Float
    ) -> ModelEntity {
        let entity = makeCylinder(named: name, radius: radius, height: height, position: position, material: material)
        configureDynamicPhysics(for: entity, mass: mass)
        return entity
    }

    private func configure(_ entity: ModelEntity, name: String, position: SIMD3<Float>) {
        entity.name = name
        entity.position = position
        // RealityKit hit testing only works against entities that have collision shapes.
        entity.generateCollisionShapes(recursive: false)
    }

    private func configureStaticPhysics(for entity: ModelEntity) {
        entity.components.set(
            PhysicsBodyComponent(
                massProperties: .default,
                material: .generate(staticFriction: 0.9, dynamicFriction: 0.8, restitution: 0.1),
                mode: .static
            )
        )
    }

    private func configureDynamicPhysics(for entity: ModelEntity, mass: Float) {
        entity.components.set(
            PhysicsBodyComponent(
                massProperties: .init(mass: mass),
                material: .generate(staticFriction: 0.7, dynamicFriction: 0.5, restitution: 0.25),
                mode: .dynamic
            )
        )
        entity.components.set(PhysicsMotionComponent())
    }

    private func addLights(to root: AnchorEntity) {
        addDirectionalLight(
            named: "softWindowLight",
            color: UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1.0),
            intensity: 1_800,
            position: [-3.0, 3.2, 2.5],
            target: [0, 0.8, 0],
            to: root
        )
        addPointLight(
            named: "warmCeilingBounce",
            color: UIColor(red: 1.0, green: 0.82, blue: 0.58, alpha: 1.0),
            intensity: 1_200,
            attenuationRadius: 5.0,
            position: [0, 2.4, 0],
            to: root
        )
        addPointLight(
            named: "leftBedsideLamp",
            color: UIColor(red: 1.0, green: 0.72, blue: 0.42, alpha: 1.0),
            intensity: 650,
            attenuationRadius: 2.2,
            position: [-1.8, 1.1, -1.2],
            to: root
        )
        addPointLight(
            named: "rightBedsideLamp",
            color: UIColor(red: 1.0, green: 0.72, blue: 0.42, alpha: 1.0),
            intensity: 650,
            attenuationRadius: 2.2,
            position: [1.8, 1.1, -1.2],
            to: root
        )
        addSpotLight(
            named: "softAccentLight",
            color: UIColor(red: 1.0, green: 0.86, blue: 0.68, alpha: 1.0),
            intensity: 900,
            innerAngle: 35,
            outerAngle: 70,
            attenuationRadius: 5.0,
            position: [0, 2.7, 2.4],
            target: [0, 0.6, 0],
            to: root
        )
    }

    private func addDirectionalLight(
        named name: String,
        color: UIColor,
        intensity: Float,
        position: SIMD3<Float>,
        target: SIMD3<Float>,
        to root: AnchorEntity
    ) {
        let light = Entity()
        light.name = name

        var component = DirectionalLightComponent()
        component.color = color
        component.intensity = intensity
        light.components.set(component)
        light.look(at: target, from: position, relativeTo: nil)
        root.addChild(light)
    }

    private func addPointLight(
        named name: String,
        color: UIColor,
        intensity: Float,
        attenuationRadius: Float,
        position: SIMD3<Float>,
        to root: AnchorEntity
    ) {
        let light = Entity()
        light.name = name
        light.position = position

        var component = PointLightComponent()
        component.color = color
        component.intensity = intensity
        component.attenuationRadius = attenuationRadius
        light.components.set(component)
        root.addChild(light)
    }

    private func addSpotLight(
        named name: String,
        color: UIColor,
        intensity: Float,
        innerAngle: Float,
        outerAngle: Float,
        attenuationRadius: Float,
        position: SIMD3<Float>,
        target: SIMD3<Float>,
        to root: AnchorEntity
    ) {
        let light = Entity()
        light.name = name

        let component = SpotLightComponent(
            color: color,
            intensity: intensity,
            innerAngleInDegrees: innerAngle,
            outerAngleInDegrees: outerAngle,
            attenuationRadius: attenuationRadius
        )
        light.components.set(component)
        light.look(at: target, from: position, relativeTo: nil)
        root.addChild(light)
    }

    private func addCamera(to root: AnchorEntity) {
        cameraRig.name = "cameraRig"
        motionRig.name = "motionRig"
        cameraEntity.name = "camera"

        cameraRig.position = [0, Constants.cameraHeight, 3]
        cameraEntity.components.set(PerspectiveCameraComponent())
        cameraEntity.position = .zero

        motionRig.addChild(cameraEntity)
        cameraRig.addChild(motionRig)
        root.addChild(cameraRig)
    }

    private func addMoveIndicator(to root: AnchorEntity) {
        let outerMaterial = SimpleMaterial(
            color: UIColor(red: 1.0, green: 0.78, blue: 0.34, alpha: 0.95),
            roughness: 0.2,
            isMetallic: false
        )
        let innerMaterial = SimpleMaterial(
            color: UIColor(red: 1.0, green: 0.96, blue: 0.78, alpha: 0.92),
            roughness: 0.1,
            isMetallic: false
        )

        let outerDisc = ModelEntity(
            mesh: .generateCylinder(height: Constants.moveIndicatorThickness, radius: Constants.moveIndicatorRadius),
            materials: [outerMaterial]
        )
        outerDisc.name = "moveIndicatorOuter"

        let innerDisc = ModelEntity(
            mesh: .generateCylinder(height: Constants.moveIndicatorThickness * 1.2, radius: Constants.moveIndicatorRadius * 0.38),
            materials: [innerMaterial]
        )
        innerDisc.name = "moveIndicatorInner"
        innerDisc.position.y = Constants.moveIndicatorThickness * 0.65

        moveIndicator.name = "moveIndicator"
        moveIndicator.isEnabled = false
        moveIndicator.addChild(outerDisc)
        moveIndicator.addChild(innerDisc)
        root.addChild(moveIndicator)
    }

    private func installSpatialAmbience(on target: Entity) {
        ambienceEntity.removeFromParent()
        ambiencePlaybackController?.stop()
        ambiencePlaybackController = nil

        ambienceEntity.name = "ambienceSource"
        ambienceEntity.position = Constants.ambienceSourceOffset
        ambienceEntity.components.set(SpatialAudioComponent())
        target.addChild(ambienceEntity)

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let configuration = AudioFileResource.Configuration(
                    loadingStrategy: .preload,
                    shouldLoop: true,
                    shouldRandomizeStartTime: false
                )
                let ambience = try await AudioFileResource(
                    named: Constants.ambienceAudioName,
                    in: .main,
                    configuration: configuration
                )
                self.ambiencePlaybackController = self.ambienceEntity.playAudio(ambience)
            } catch {
                self.ambiencePlaybackController = nil
            }
        }
    }

    // MARK: - Input

    private func installGestures(on arView: ARView) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1

        tapGesture.require(toFail: panGesture)
        arView.addGestureRecognizer(tapGesture)
        arView.addGestureRecognizer(panGesture)
        roomTapGesture = tapGesture
        roomPanGesture = panGesture
    }

    private func setInteractionMode(_ mode: VirtualRoomInteractionMode) {
        guard let arView else {
            interactionMode = mode
            return
        }

        interactionMode = mode
        let isExploring = mode == .explore
        roomTapGesture?.isEnabled = isExploring
        roomPanGesture?.isEnabled = isExploring

        if isExploring {
            cutoutEditor.detachInteraction()
        } else {
            releaseHeldEntityIfNeeded()
            let projector = NonARPlaneProjector(
                planeTransform: floorPlaneTransform,
                horizontalBounds: -Constants.movementLimit...Constants.movementLimit
            )
            cutoutEditor.attachInteraction(
                to: arView,
                surfaceProjector: projector
            ) { [weak self, weak arView] point in
                guard let self, let arView else { return }
                self.handleEditTap(at: point, in: arView, projector: projector)
            }
        }
    }

    private func handleEditTap(
        at point: CGPoint,
        in arView: ARView,
        projector: NonARPlaneProjector
    ) {
        guard cutoutEditor.selectedContentType == .model || !cutoutEditor.cutoutAssets.isEmpty else {
            return
        }
        let cameraTransform = cameraEntity.transformMatrix(relativeTo: nil)
        if cutoutEditor.selectedContentType == .doodle &&
            cutoutEditor.selectedSpawnMode == .cameraRoam {
            handlePlacementResult(cutoutEditor.placeRoaming(cameraTransform: cameraTransform))
            return
        }

        guard let projection = projector.project(point, in: arView) else {
            return
        }
        handlePlacementResult(cutoutEditor.placeOnPlane(
            at: projection.position,
            normal: projection.normal,
            cameraTransform: cameraTransform
        ))
    }

    private func handlePlacementResult(_ result: CutoutPlacementResult) {
        switch result {
        case .placed:
            onPlacementMessageChanged?(nil)
        case .loading(let message):
            onPlacementMessageChanged?(message)
        case .limitReached(let maximum):
            onPlacementMessageChanged?("Room full (\(maximum) objects). Delete one to place another.")
        case .missingAsset:
            onPlacementMessageChanged?("Choose a cutout before placing it.")
        case .missingModel:
            onPlacementMessageChanged?("Choose a 3D model before placing it.")
        case .creationFailed(let message):
            onPlacementMessageChanged?(message)
        }
    }

    private var floorPlaneTransform: simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.0 = [1, 0, 0, 0]
        transform.columns.1 = [0, 0, -1, 0]
        transform.columns.2 = [0, 1, 0, 0]
        return transform
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }

        motionManager.deviceMotionUpdateInterval = Constants.motionUpdateInterval
        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: motionQueue) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else {
                return
            }

            let deviceQuaternion = simd_quatf(attitude.quaternion)
            self.motionOrientationStore.write(
                quaternion: deviceQuaternion,
                timestamp: motion?.timestamp ?? 0
            )
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let arView else {
            return
        }

        let location = recognizer.location(in: arView)
        let hits = arView.hitTest(location)

        if let heldEntity {
            launchHeldEntity(heldEntity)
            return
        }

        if let pickupEntity = hits.compactMap({ pickupEntity(from: $0.entity) }).first {
            pickUpEntity(pickupEntity)
            return
        }

        guard
            let floorEntity,
            let floorHit = hits.first(where: { $0.entity === floorEntity })
        else {
            return
        }

        destination = cameraDestination(from: floorHit.position)
        showMoveIndicator(at: floorHit.position)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let arView = recognizer.view else {
            return
        }

        let translation = recognizer.translation(in: arView)
        manualYawOffset += Float(translation.x) * Constants.panYawSensitivity
        recognizer.setTranslation(.zero, in: arView)
    }

    private func cameraDestination(from floorHitPosition: SIMD3<Float>) -> SIMD3<Float> {
        [
            clamped(floorHitPosition.x, min: -Constants.movementLimit, max: Constants.movementLimit),
            Constants.cameraHeight,
            clamped(floorHitPosition.z, min: -Constants.movementLimit, max: Constants.movementLimit)
        ]
    }

    // MARK: - Frame Updates

    private func subscribeToSceneUpdates(in arView: ARView) {
        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.update(deltaTime: Float(event.deltaTime))
        }
    }

    private func update(deltaTime: Float) {
        updateCameraOrientation(deltaTime: deltaTime)
        updateCameraPosition(deltaTime: deltaTime)
        updateMoveIndicator(deltaTime: deltaTime)
        updateHeldEntity(deltaTime: deltaTime)
        cutoutEditor.update(deltaTime: deltaTime)
    }

    private func updateCameraOrientation(deltaTime: Float) {
        if let snapshot = motionOrientationStore.read() {
            currentDeviceQuaternion = snapshot.quaternion
            if calibrationQuaternion == nil {
                calibrationQuaternion = snapshot.quaternion
            }
        }
        guard
            let interfaceOrientation = currentInterfaceOrientation(),
            let currentDeviceQuaternion
        else {
            return
        }

        if motionInterfaceOrientation != interfaceOrientation {
            motionInterfaceOrientation = interfaceOrientation
            self.calibrationQuaternion = currentDeviceQuaternion
            smoothedMotionQuaternion = nil
        }

        guard let calibrationQuaternion = self.calibrationQuaternion else {
            return
        }

        let relativeDeviceRotation = calibrationQuaternion.inverse * currentDeviceQuaternion
        let targetCameraRotation = cameraSpaceRotation(
            from: relativeDeviceRotation,
            interfaceOrientation: interfaceOrientation
        )
        let cameraRotation = smoothedCameraRotation(
            target: targetCameraRotation,
            deltaTime: deltaTime
        )

        cameraRig.orientation = simd_quatf(angle: manualYawOffset, axis: [0, 1, 0])
        motionRig.orientation = cameraRotation
    }

    private func updateCameraPosition(deltaTime: Float) {
        guard let destination else {
            return
        }

        let current = cameraRig.position
        let offset = destination - current
        let distance = simd_length(offset)

        if distance <= Constants.destinationTolerance {
            cameraRig.position = destination
            self.destination = nil
            hideMoveIndicator()
            return
        }

        let step = min(distance, Constants.cameraMoveSpeed * deltaTime)
        cameraRig.position = current + simd_normalize(offset) * step
    }

    private func calibrateCamera() {
        calibrationQuaternion = motionOrientationStore.read()?.quaternion ?? currentDeviceQuaternion
        smoothedMotionQuaternion = nil
        cameraRig.orientation = simd_quatf(angle: manualYawOffset, axis: [0, 1, 0])
        motionRig.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        cameraEntity.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
    }

    // MARK: - Math

    private func currentInterfaceOrientation() -> UIInterfaceOrientation? {
        guard
            let interfaceOrientation = arView?.window?.windowScene?.interfaceOrientation,
            interfaceOrientation != .unknown
        else {
            return motionInterfaceOrientation
        }

        return interfaceOrientation
    }

    private func cameraSpaceRotation(
        from deviceRotation: simd_quatf,
        interfaceOrientation: UIInterfaceOrientation
    ) -> simd_quatf {
        // Core Motion reports attitude in the device's portrait-native basis.
        // Express that rotation in the active screen basis before applying it to
        // the RealityKit camera, whose local +X is right, +Y is up, and -Z is forward.
        let screenToPortraitAngle: Float
        switch interfaceOrientation {
        case .portrait:
            screenToPortraitAngle = 0
        case .portraitUpsideDown:
            screenToPortraitAngle = .pi
        case .landscapeLeft:
            screenToPortraitAngle = .pi / 2
        case .landscapeRight:
            screenToPortraitAngle = -.pi / 2
        default:
            screenToPortraitAngle = 0
        }

        let screenToPortrait = simd_quatf(
            angle: screenToPortraitAngle,
            axis: [0, 0, 1]
        )
        return screenToPortrait.inverse * deviceRotation * screenToPortrait
    }

    private func smoothedCameraRotation(target: simd_quatf, deltaTime: Float) -> simd_quatf {
        guard let current = smoothedMotionQuaternion else {
            smoothedMotionQuaternion = target
            return target
        }

        let blend = 1 - exp(-Constants.motionSmoothingRate * max(deltaTime, 0))
        let smoothed = simd_slerp(current, target, blend)
        smoothedMotionQuaternion = smoothed
        return smoothed
    }

    private func showMoveIndicator(at floorHitPosition: SIMD3<Float>) {
        moveIndicatorTime = 0
        moveIndicator.position = [
            clamped(floorHitPosition.x, min: -Constants.movementLimit, max: Constants.movementLimit),
            floorHitPosition.y + Constants.moveIndicatorHover,
            clamped(floorHitPosition.z, min: -Constants.movementLimit, max: Constants.movementLimit)
        ]
        moveIndicator.scale = .one
        moveIndicator.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        moveIndicator.isEnabled = true
    }

    private func hideMoveIndicator() {
        moveIndicator.isEnabled = false
        moveIndicatorTime = 0
    }

    private func updateMoveIndicator(deltaTime: Float) {
        guard moveIndicator.isEnabled else {
            return
        }

        moveIndicatorTime += deltaTime
        let pulse = 1 + 0.08 * sin(moveIndicatorTime * Constants.moveIndicatorPulseSpeed * .pi * 2)
        moveIndicator.scale = [pulse, 1, pulse]
        moveIndicator.orientation = simd_quatf(
            angle: moveIndicatorTime * Constants.moveIndicatorSpinSpeed * .pi * 2,
            axis: [0, 1, 0]
        )
    }

    private func pickUpEntity(_ entity: ModelEntity) {
        destination = nil
        hideMoveIndicator()
        heldEntity = entity

        var physicsBody = entity.components[PhysicsBodyComponent.self] ?? PhysicsBodyComponent()
        physicsBody.mode = .kinematic
        entity.components.set(physicsBody)

        var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity = .zero
        motion.angularVelocity = .zero
        entity.components.set(motion)
    }

    private func launchHeldEntity(_ entity: ModelEntity) {
        guard let sceneRoot else {
            return
        }

        let launchTransform = heldTransform()
        entity.setTransformMatrix(launchTransform.matrix, relativeTo: sceneRoot)

        var physicsBody = entity.components[PhysicsBodyComponent.self] ?? PhysicsBodyComponent()
        physicsBody.mode = .dynamic
        entity.components.set(physicsBody)

        var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        let forward = simd_normalize(launchTransform.matrix.columns.2.xyz * -1)
        motion.linearVelocity = forward * Constants.launchSpeed
        motion.angularVelocity = [0, 2.2, 0]
        entity.components.set(motion)

        heldEntity = nil
    }

    private func releaseHeldEntityIfNeeded() {
        guard let heldEntity else { return }
        var physicsBody = heldEntity.components[PhysicsBodyComponent.self] ?? PhysicsBodyComponent()
        physicsBody.mode = .dynamic
        heldEntity.components.set(physicsBody)

        var motion = heldEntity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity = .zero
        motion.angularVelocity = .zero
        heldEntity.components.set(motion)
        self.heldEntity = nil
    }

    private func updateHeldEntity(deltaTime: Float) {
        guard
            let heldEntity,
            let sceneRoot
        else {
            return
        }

        let targetTransform = heldTransform()
        let currentTransform = heldEntity.transformMatrix(relativeTo: sceneRoot)
        let blend = 1 - exp(-Constants.pickupFollowRate * max(deltaTime, 0))
        let nextTranslation = simd_mix(currentTransform.columns.3.xyz, targetTransform.matrix.columns.3.xyz, SIMD3(repeating: blend))

        heldEntity.setPosition(nextTranslation, relativeTo: sceneRoot)
        heldEntity.setOrientation(targetTransform.rotation, relativeTo: sceneRoot)
    }

    private func heldTransform() -> Transform {
        let cameraTransform = cameraEntity.transformMatrix(relativeTo: sceneRoot)
        let forward = simd_normalize(cameraTransform.columns.2.xyz * -1)
        let basePosition = cameraTransform.columns.3.xyz
        let targetPosition = basePosition + forward * Constants.pickupHoldDistance + SIMD3<Float>(0, Constants.pickupHoldHeightOffset, 0)

        return Transform(
            scale: .one,
            rotation: cameraEntity.orientation(relativeTo: sceneRoot),
            translation: targetPosition
        )
    }

    private func pickupEntity(from entity: Entity) -> ModelEntity? {
        var current: Entity? = entity

        while let candidate = current {
            if
                let model = candidate as? ModelEntity,
                model.name.hasPrefix(Constants.pickupNamePrefix)
            {
                return model
            }
            current = candidate.parent
        }

        return nil
    }

    private func clamped(_ value: Float, min minimum: Float, max maximum: Float) -> Float {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

private extension simd_float4 {
    var xyz: SIMD3<Float> {
        [x, y, z]
    }
}

private extension simd_quatf {
    init(_ quaternion: CMQuaternion) {
        self.init(
            ix: Float(quaternion.x),
            iy: Float(quaternion.y),
            iz: Float(quaternion.z),
            r: Float(quaternion.w)
        )
    }
}

#Preview {
    VirtualRoomView()
        .environmentObject(ArtworkLibraryStore(repository: PreviewArtworkRepository()))
}
