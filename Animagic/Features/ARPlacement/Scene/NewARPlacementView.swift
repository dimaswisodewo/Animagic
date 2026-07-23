//
//  NewARPlacementView.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 17/07/26.
//

import ARKit
import os
import RealityKit
import SwiftUI
import UIKit

enum NewARSceneCommand: Equatable {
    case place(UUID)
    case clearSelection(UUID)
    case delete(UUID)
    case flipFacing(UUID)
    case undoDelete(UUID)
    case discardUndo(UUID)
    case cancelPencilInteraction(UUID)
    case capturePhoto(UUID)
}

private enum ARPhotoCaptureError: LocalizedError {
    case viewUnavailable
    case snapshotFailed

    var errorDescription: String? {
        switch self {
        case .viewUnavailable:
            "The AR camera is not ready yet. Please try again."
        case .snapshotFailed:
            "AniMagix couldn’t capture this AR scene. Please try again."
        }
    }
}

@MainActor
protocol ARPlacementFeedbackProviding: AnyObject {
    func selectionChanged()
    func dragStarted()
    func placementSucceeded()
    func boundaryReached()
    func detent()
    func pencilTargetAcquired()
    func pencilRotationCommitted()
    func warning()
    func error()
}

@MainActor
extension HapticFeedbackManager: ARPlacementFeedbackProviding {
    func selectionChanged() {
        play(.selection)
    }

    func dragStarted() {
        play(.dragStarted)
    }

    func placementSucceeded() {
        play(.placementCompleted)
    }

    func boundaryReached() {
        play(.boundaryReached)
    }

    func detent() {
        play(.detent)
    }

    func pencilTargetAcquired() {
        play(.pencilTargetAcquired)
    }

    func pencilRotationCommitted() {
        play(.pencilRotationCompleted)
    }

    func warning() {
        play(.warning)
    }

    func error() {
        play(.error)
    }
}

struct NewARPlacementView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @Environment(DrawingSessionManager.self) private var drawingSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HapticFeedbackManager.self) private var haptics

    @State private var selectedContentType = PlacementContentType.doodle
    @State private var selectedCutoutID: CutoutAsset.ID?
    @State private var selectedModelID = PlaceableUSDZModel.all.first?.id
    @State private var selectedAnimalLocomotion = AnimalLocomotion.generic
    @State private var placementStatus: ARPlacementStatus = .searching
    @State private var placedObjectSelection: PlacedObjectSelection?
    @State private var selectedObjectElevationMeters: Float = 0
    @State private var isAdjustingObjectElevation = false
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
    @State private var hasFoundInitialSurface = false
    @State private var isCapturingPhoto = false
    @State private var isShowingCaptureFlash = false
    @State private var captureMessage: String?
    @State private var captureErrorMessage: String?
    @State private var captureFlashTask: Task<Void, Never>?
    @State private var captureMessageTask: Task<Void, Never>?
    @AppStorage("hasCompletedARPencilRotation") private var hasCompletedPencilRotation = false
    @State private var pencilHint: String?
    @State private var pencilHintTask: Task<Void, Never>?
    @State private var returnRecoveryState = ARReturnRecoveryState()
    @State private var recoveryFallbackTask: Task<Void, Never>?
    @State private var didLeaveActiveScene = false

    private enum CameraPermissionState {
        case checking
        case authorized
        case denied
    }

    private enum Layout {
        static let topControlInset: CGFloat = 24
        static let iconButtonDiameter: CGFloat = 84
        static let backpackTopGap: CGFloat = 12
        static let backpackMinimumHeight: CGFloat = 220
    }

    private let initialCutoutID: CutoutAsset.ID?
    private let maximumObjectCount = 20
    private var feedback: any ARPlacementFeedbackProviding { haptics }

    init(initialCutoutID: CutoutAsset.ID? = nil) {
        self.initialCutoutID = initialCutoutID
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
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            checkCameraPermission()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkCameraPermission()
                if didLeaveActiveScene {
                    didLeaveActiveScene = false
                    beginReturnRecovery()
                }
            } else {
                didLeaveActiveScene = true
                updateARReadiness(.unavailable)
                sceneCommand = .cancelPencilInteraction(UUID())
            }
        }
        .onChange(of: router.presentedFullScreenCovers.contains(.canvas)) { wasPresented, isPresented in
            guard wasPresented, !isPresented else { return }
            restoreAfterCanvas()
        }
    }

    @ViewBuilder
    private var arContent: some View {
        ZStack(alignment: .bottom) {
            ARRealityViewRepresentable(
                cutoutAssets: arCutoutAssets,
                selectedCutoutID: selectedCutoutID,
                spawnAnimalLocomotion: selectedAnimalLocomotion,
                selectedObjectAnimalLocomotion: placedObjectSelection?.animalLocomotion,
                selectedContentType: selectedContentType,
                selectedModelID: selectedModelID,
                placedObjectSelection: $placedObjectSelection,
                selectedObjectElevationMeters: $selectedObjectElevationMeters,
                isAdjustingObjectElevation: $isAdjustingObjectElevation,
                placementStatus: $placementStatus,
                objectCount: $objectCount,
                undoAvailable: $undoAvailable,
                command: sceneCommand,
                isAppSceneActive: scenePhase == .active,
                isImmersive: isImmersive,
                onExitImmersive: exitImmersive,
                onPencilTargetHovered: showPencilCoachMark,
                onPencilTargetMissing: showPencilTargetHint,
                onPencilRotationCompleted: completePencilCoachMark,
                onPhotoCaptured: handlePhotoCaptureResult,
                onReadinessChanged: updateARReadiness,
                onSessionInterrupted: handleARSessionInterruption,
                feedback: feedback
            )
            .ignoresSafeArea()

            if !hasFoundInitialSurface {
                ARLoadingOverlayView(status: placementStatus)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if isShowingCaptureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if !isImmersive {
                controlsOverlay
            }

            if isImmersive, showsImmersiveHint || pencilHint != nil {
                VStack(spacing: 8) {
                    if let pencilHint {
                        ARTransientHint(message: pencilHint)
                            .transition(transientScaleTransition)
                    }

                    if showsImmersiveHint {
                        ARTransientHint(message: "Tap empty space to show controls")
                            .transition(transientScaleTransition)
                    }
                }
                .padding(.bottom, 24)
            }

            if returnRecoveryState.showsRecoveryOverlay {
                ARReturnRecoveryView(
                    showsActions: returnRecoveryState.showsFallbackActions,
                    onKeepTrying: keepTryingRecovery,
                    onExit: exitARFromRecovery
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.32), value: placedObjectSelection)
        .animation(reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection, value: undoAvailable)
        .animation(reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.panelEntrance, value: pencilHint)
        .animation(reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.panelEntrance, value: showsImmersiveHint)
        .animation(reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.panelExit, value: hasFoundInitialSurface)
        .animation(.easeOut(duration: 0.12), value: isShowingCaptureFlash)
        .animation(
            reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.panelEntrance,
            value: returnRecoveryState.phase
        )
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            synchronizeInitialSelection()
        }
        .onChange(of: arCutoutItems.map(\.id)) { _, _ in
            synchronizeInitialSelection()
        }
        .onChange(of: selectedCutoutID) { _, newID in
            guard placedObjectSelection == nil,
                  let asset = arCutoutAssets.first(where: { $0.id == newID }),
                  let suggested = suggestedLocomotion(for: asset) else { return }
            selectedAnimalLocomotion = suggested
        }
        .onChange(of: placementStatus) { _, newStatus in
            if newStatus == .ready {
                hasFoundInitialSurface = true
            }
        }
        .onChange(of: placedObjectSelection?.objectID) { _, selectedObjectID in
            guard selectedObjectID != nil, isBackpackExpanded else { return }
            setBackpackExpanded(false)
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
            pencilHintTask?.cancel()
            captureFlashTask?.cancel()
            captureMessageTask?.cancel()
            recoveryFallbackTask?.cancel()
        }
        .alert("Camera", isPresented: captureErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(captureErrorMessage ?? "The photo couldn’t be saved.")
        }
    }

    private func showPencilCoachMark() {
        guard !hasCompletedPencilRotation else { return }
        showPencilHint("Squeeze and roll to rotate", duration: .seconds(3))
    }

    private func showPencilTargetHint() {
        showPencilHint("Hover over an object", duration: .milliseconds(1_800))
    }

    private func completePencilCoachMark() {
        hasCompletedPencilRotation = true
        pencilHintTask?.cancel()
        pencilHint = nil
    }

    private func showPencilHint(_ message: String, duration: Duration) {
        pencilHintTask?.cancel()
        pencilHint = message
        pencilHintTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            pencilHint = nil
        }
    }

    private var controlsOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 12) {
                    topControlBar
                    statusOverlay
                    Spacer()

                    if undoAvailable {
                        ARDeleteUndoToast {
                            undoDismissTask?.cancel()
                            sceneCommand = .undoDelete(UUID())
                        }
                        .allowsHitTesting(returnRecoveryState.readiness.allowsInteraction)
                        .transition(transientBottomTransition)
                    }

                    bottomControlBar
                }

                backpackControl(height: backpackShelfHeight(for: geometry.size.height))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: [.top, .trailing])
    }

    private var topControlBar: some View {
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
                            id: "help",
                            icon: "questionmark",
                            backgroundColor: .green,
                            innerBorderColor: Color.Palette.g400,
                            action: {
                                isTopMenuExpanded = false
                                router.push(.help)
                            }
                        ),
                        ExpandableButtonItem(
                            id: "immersive",
                            icon: "eye.fill",
                            backgroundColor: AnimagicTheme.orange,
                            innerBorderColor: Color.Palette.o400,
                            action: enterImmersive
                        ),
                        ExpandableButtonItem(
                            id: "camera",
                            icon: "camera.fill",
                            backgroundColor: .blue,
                            innerBorderColor: Color.Palette.b400,
                            isSelected: !isCapturingPhoto,
                            action: captureARPhoto
                        )
                    ]
                )

                AnimagicIconButton(
                    icon: "paintbrush.fill",
                    backgroundColor: .yellow,
                    innerBorderColor: Color.Palette.y400,
                    isSelected: selectedContentType == .doodle,
                    action: presentCanvas
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, Layout.topControlInset)
        .padding(.bottom, 24)
    }

    private var statusOverlay: some View {
        VStack(spacing: 8) {
            if shouldShowStatus {
                NewARStatusPill(status: placementStatus)
                    .animation(
                        reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection,
                        value: placementStatus
                    )
                    .transition(transientScaleTransition)
            }

            if let pencilHint {
                ARTransientHint(message: pencilHint)
                    .transition(transientScaleTransition)
            }

            if let captureMessage {
                ARTransientHint(message: captureMessage)
                    .transition(transientScaleTransition)
            }
        }
    }

    private var bottomControlBar: some View {
        HStack(alignment: .bottom) {
            Group {
                if let placedObjectSelection, !isBackpackExpanded {
                    NewAREditCard(
                        selection: placedObjectSelection,
                        animalLocomotion: locomotionSelection,
                        elevationMeters: $selectedObjectElevationMeters,
                        onElevationEditingChanged: { isEditing in
                            isAdjustingObjectElevation = isEditing
                        },
                        onElevationGrounded: feedback.selectionChanged,
                        onElevationMaximumReached: feedback.boundaryReached,
                        onFlip: { sceneCommand = .flipFacing(UUID()) },
                        onDone: { sceneCommand = .clearSelection(UUID()) },
                        onDelete: { sceneCommand = .delete(UUID()) }
                    )
                    .allowsHitTesting(returnRecoveryState.readiness.allowsInteraction)
                    .opacity(returnRecoveryState.readiness.allowsInteraction ? 1 : 0.55)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if placedObjectSelection == nil {
                    placementControlLayout {
                        if !isBackpackExpanded {
                            selectedContentIndicator
                        }

                        AnimagicLabelButton(
                            title: placeButtonTitle,
                            backgroundColor: AnimagicTheme.blue,
                            innerBorderColor: Color.Palette.b400,
                            isDisabled: !canPlace,
                            isDimmed: !canPlace,
                            action: { sceneCommand = .place(UUID()) }
                        )
                    }
                    .animation(
                        reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection,
                        value: selectedCutoutID
                    )
                    .animation(
                        reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection,
                        value: selectedModelID
                    )
                }
            }
            .padding(.leading, 24)
            .padding(.vertical, 24)

            Spacer()
        }
    }

    private var placementControlLayout: AnyLayout {
        if verticalSizeClass == .compact {
            AnyLayout(HStackLayout(alignment: .bottom, spacing: 10))
        } else {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        }
    }

    private func backpackControl(height: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            BackpackTabButton(
                isOpen: backpackExpansion,
                backgroundColor: AnimagicTheme.orange,
                innerBorderColor: Color.Palette.o400
            )

            if isBackpackExpanded {
                backpackSidebar(height: height)
                    .transition(sidePanelTransition)
            }
        }
        .frame(height: height)
    }

    private var backpackExpansion: Binding<Bool> {
        Binding(
            get: { isBackpackExpanded },
            set: { setBackpackExpanded($0) }
        )
    }

    private func setBackpackExpanded(_ isExpanded: Bool) {
        guard isBackpackExpanded != isExpanded else { return }

        if isExpanded, placedObjectSelection != nil {
            sceneCommand = .clearSelection(UUID())
        }

        withAnimation(reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.sidebar) {
            isBackpackExpanded = isExpanded
        }
    }

    private var sidePanelTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .trailing).combined(with: .opacity)
    }

    private func backpackSidebar(height: CGFloat) -> some View {
        BackpackSidebar(
            tabs: backpackTabs,
            items: backpackItems,
            initialTab: selectedContentType == .doodle ? "Doodle" : "3D Model",
            onTabChanged: { tab in
                let newContentType: PlacementContentType = tab == "3D Model" ? .model : .doodle
                guard selectedContentType != newContentType else { return }
                selectedContentType = newContentType
                feedback.selectionChanged()
            },
            onItemTapped: selectBackpackItem,
            emptyContent: { tab in
                backpackEmptyContent(for: tab)
            },
            itemContent: { itemID in
                backpackItemContent(for: itemID)
            }
        )
        .frame(width: backpackShelfWidth, height: height)
    }

    private func backpackEmptyContent(for tab: String) -> AnyView {
        guard tab == "Doodle" else {
            return AnyView(
                AnimagicEmptyState(
                    icon: "shippingbox.fill",
                    title: "Nothing Here Yet",
                    message: "There are no items in this section.",
                    isCompact: true
                )
            )
        }

        return AnyView(
            AnimagicEmptyState(
                icon: "paintbrush.pointed.fill",
                title: "No Doodles Yet",
                message: "Draw a doodle for your backpack, or choose a 3D Model.",
                actionTitle: "Draw a Doodle",
                actionIcon: "paintbrush.fill",
                isCompact: true,
                action: presentCanvas
            )
        )
    }

    private var backpackTabs: [String] {
        ["Doodle", "3D Model"]
    }

    private var backpackItems: [String: [String]] {
        [
            "Doodle": arCutoutItems.map { "doodle:\($0.id.uuidString)" },
            "3D Model": PlaceableUSDZModel.all.map { "model:\($0.id.rawValue)" }
        ]
    }

    private var backpackShelfWidth: CGFloat {
        verticalSizeClass == .compact ? 340 : 400
    }

    private func backpackShelfHeight(for containerHeight: CGFloat) -> CGFloat {
        let topControlsBottom = Layout.topControlInset
            + Layout.iconButtonDiameter
            + Layout.backpackTopGap
        return max(Layout.backpackMinimumHeight, containerHeight - topControlsBottom)
    }

    private func selectBackpackItem(_ itemID: String) {
        if itemID.hasPrefix("doodle:"),
           let cutoutID = UUID(uuidString: String(itemID.dropFirst("doodle:".count))) {
            selectedContentType = .doodle
            selectedCutoutID = cutoutID
        } else if let rawID = itemID.split(separator: ":", maxSplits: 1).last,
                  let modelID = PlaceableUSDZModel.ID(rawValue: String(rawID)) {
            selectedContentType = .model
            selectedModelID = modelID
        }

        feedback.selectionChanged()
    }

    private func backpackItemContent(for itemID: String) -> AnyView {
        if let rawID = itemID.split(separator: ":", maxSplits: 1).last,
           itemID.hasPrefix("doodle:"),
           let cutoutID = UUID(uuidString: String(rawID)),
           let item = arCutoutItems.first(where: { $0.id == cutoutID }) {
            return AnyView(
                BackpackSidebarItemCard(
                    title: item.title,
                    isSelected: selectedCutoutID == item.id
                ) {
                    Image(uiImage: item.cutout.image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
            )
        }

        if let rawID = itemID.split(separator: ":", maxSplits: 1).last,
           itemID.hasPrefix("model:"),
           let modelID = PlaceableUSDZModel.ID(rawValue: String(rawID)),
           let model = PlaceableUSDZModel.model(withID: modelID) {
            return AnyView(
                BackpackSidebarItemCard(title: model.title, isSelected: selectedModelID == model.id) {
                    ARUSDZThumbnail(model: model)
                }
            )
        }

        return AnyView(EmptyView())
    }

    private var transientScaleTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity.animation(AnimagicMotion.reduced)
        }

        return .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity)
                .animation(AnimagicMotion.panelEntrance),
            removal: .scale(scale: 0.96).combined(with: .opacity)
                .animation(AnimagicMotion.panelExit)
        )
    }

    private var transientBottomTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity.animation(AnimagicMotion.reduced)
        }

        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity)
                .animation(AnimagicMotion.panelEntrance),
            removal: .move(edge: .bottom).combined(with: .opacity)
                .animation(AnimagicMotion.panelExit)
        )
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
            return selectedCutoutID != nil && !arCutoutItems.isEmpty
        case .model:
            return selectedModelID != nil
        }
    }

    private var selectedCutoutAsset: CutoutAsset? {
        guard selectedContentType == .doodle,
              let selectedCutoutID else { return nil }
        return arCutoutAssets.first(where: { $0.id == selectedCutoutID })
    }

    private var selectedModel: PlaceableUSDZModel? {
        guard selectedContentType == .model,
              let selectedModelID else { return nil }
        return PlaceableUSDZModel.model(withID: selectedModelID)
    }

    @ViewBuilder
    private var selectedContentIndicator: some View {
        if let asset = selectedCutoutAsset {
            ARSelectedContentIndicator(
                kindTitle: "Doodle",
                title: titleForCutout(asset),
                accentColor: AnimagicTheme.orange
            ) {
                Image(uiImage: asset.image)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
            .id("doodle-\(asset.id.uuidString)")
            .transition(selectedIndicatorTransition)
        } else if let model = selectedModel {
            ARSelectedContentIndicator(
                kindTitle: "3D Model",
                title: model.title,
                accentColor: AnimagicTheme.blue
            ) {
                ARUSDZThumbnail(model: model)
                    .padding(2)
            }
            .id("model-\(model.id.rawValue)")
            .transition(selectedIndicatorTransition)
        }
    }

    private var selectedIndicatorTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.96, anchor: .bottomLeading).combined(with: .opacity)
    }

    private func titleForCutout(_ cutout: CutoutAsset) -> String {
        guard let drawing = artworkStore.drawing(id: cutout.sourceDrawingID) else {
            return "My Doodle"
        }
        let title = drawing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "My Doodle" : title
    }

    private var arCutoutItems: [BackpackCutoutItem] {
        ArtworkLibraryPresentation.backpackCutoutItems(
            drawings: artworkStore.savedDrawings,
            cutouts: artworkStore.cutoutLibrary,
            temporaryCutoutID: initialCutoutID
        )
    }

    private var arCutoutAssets: [CutoutAsset] {
        arCutoutItems.map(\.cutout)
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

    private var locomotionSelection: Binding<AnimalLocomotion> {
        Binding(
            get: { placedObjectSelection?.animalLocomotion ?? selectedAnimalLocomotion },
            set: { locomotion in
                guard let selection = placedObjectSelection,
                      selection.animalLocomotion != nil else { return }
                placedObjectSelection = PlacedObjectSelection(
                    objectID: selection.objectID,
                    content: .doodle(locomotion),
                    elevationMeters: selection.elevationMeters
                )
                feedback.selectionChanged()
            }
        )
    }

    private func synchronizeInitialSelection() {
        if arCutoutAssets.isEmpty {
            selectedCutoutID = nil
            selectedContentType = .model
            return
        }

        if let selectedCutoutID,
           arCutoutAssets.contains(where: { $0.id == selectedCutoutID }) {
            return
        }

        let initialAsset = initialCutoutID.flatMap { id in
            arCutoutAssets.first(where: { $0.id == id })
        } ?? arCutoutAssets.first
        selectedCutoutID = initialAsset?.id
        if let suggested = suggestedLocomotion(for: initialAsset) {
            selectedAnimalLocomotion = suggested
        }
    }

    private func presentCanvas() {
        drawingSession.clearPendingARCutout()
        sceneCommand = .cancelPencilInteraction(UUID())
        router.presentFullScreenCover(.canvas)
    }

    private func captureARPhoto() {
        guard !isCapturingPhoto else { return }

        isTopMenuExpanded = false
        isCapturingPhoto = true
        captureErrorMessage = nil
        sceneCommand = .capturePhoto(UUID())
    }

    private func handlePhotoCaptureResult(_ result: Result<UIImage, Error>) {
        switch result {
        case .success(let image):
            haptics.play(.cameraShutter)
            showCaptureFlash()

            Task { @MainActor in
                do {
                    try await NativeCameraPhotoLibrarySaver.savePhoto(image)
                    isCapturingPhoto = false
                    showCaptureMessage("Photo saved to Photos")
                } catch {
                    isCapturingPhoto = false
                    captureErrorMessage = error.localizedDescription
                    feedback.error()
                }
            }
        case .failure(let error):
            isCapturingPhoto = false
            captureErrorMessage = error.localizedDescription
            feedback.error()
        }
    }

    private func showCaptureFlash() {
        captureFlashTask?.cancel()
        isShowingCaptureFlash = true
        captureFlashTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            isShowingCaptureFlash = false
        }
    }

    private func showCaptureMessage(_ message: String) {
        captureMessageTask?.cancel()
        captureMessage = message
        captureMessageTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            captureMessage = nil
        }
    }

    private var captureErrorIsPresented: Binding<Bool> {
        Binding(
            get: { captureErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    captureErrorMessage = nil
                }
            }
        )
    }

    private func restoreAfterCanvas() {
        if let cutoutID = drawingSession.consumeARCutout(),
           let asset = arCutoutAssets.first(where: { $0.id == cutoutID }) {
            selectedCutoutID = cutoutID
            selectedContentType = .doodle
            if let suggested = suggestedLocomotion(for: asset) {
                selectedAnimalLocomotion = suggested
            }
        }
        beginReturnRecovery()
    }

    private func updateARReadiness(_ readiness: ARTrackingReadiness) {
        returnRecoveryState.updateReadiness(readiness)
        if !returnRecoveryState.showsRecoveryOverlay {
            recoveryFallbackTask?.cancel()
            recoveryFallbackTask = nil
        }
    }

    private func handleARSessionInterruption() {
        updateARReadiness(.unavailable)
        sceneCommand = .cancelPencilInteraction(UUID())
        if !router.presentedFullScreenCovers.contains(.canvas) {
            beginReturnRecovery()
        }
    }

    private func beginReturnRecovery() {
        returnRecoveryState.requireRecovery()
        scheduleRecoveryFallbackIfNeeded()
    }

    private func keepTryingRecovery() {
        returnRecoveryState.keepTrying()
        scheduleRecoveryFallbackIfNeeded()
    }

    private func scheduleRecoveryFallbackIfNeeded() {
        recoveryFallbackTask?.cancel()
        guard returnRecoveryState.phase == .recovering else { return }
        recoveryFallbackTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            returnRecoveryState.revealFallbackActions()
        }
    }

    private func exitARFromRecovery() {
        recoveryFallbackTask?.cancel()
        recoveryFallbackTask = nil
        router.popToRoot()
    }

    private func suggestedLocomotion(for asset: CutoutAsset?) -> AnimalLocomotion? {
        AnimalMotionProfileResolver.profile(for: asset).locomotion
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
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    VStack(spacing: 22) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 84, height: 84)
                            .background(AnimagicTheme.orange, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(AnimagicTheme.darkNavy, lineWidth: 4)
                            }

                        VStack(spacing: 8) {
                            Text("Camera Access Required")
                                .font(.custom("Belanosima-SemiBold", size: 32, relativeTo: .title2))
                                .foregroundStyle(AnimagicTheme.darkNavy)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)

                            Text("AniMagic needs camera access to place your doodles in AR. Enable it in Settings, then return to AniMagic.")
                                .font(.custom("Belanosima-Regular", size: 20, relativeTo: .body))
                                .foregroundStyle(Color.Token.Text.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 8) {
                            AnimagicLabelButton(
                                title: "Open Settings",
                                icon: "gearshape.fill",
                                backgroundColor: AnimagicTheme.orange,
                                innerBorderColor: Color.Palette.o400,
                                action: openAppSettings
                            )

                            AnimagicLabelButton(
                                title: "Go Back",
                                icon: "chevron.left",
                                backgroundColor: AnimagicTheme.blue,
                                innerBorderColor: Color.Palette.b400,
                                action: dismiss.callAsFunction
                            )
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 520)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(AnimagicTheme.darkNavy, lineWidth: 4)
                    }
                    .shadow(color: AnimagicTheme.darkNavy.opacity(0.18), radius: 16, y: 6)
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .background(AnimagicTheme.yellow)
        }
        .ignoresSafeArea()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct ARRealityViewRepresentable: UIViewRepresentable {
    let cutoutAssets: [CutoutAsset]
    let selectedCutoutID: CutoutAsset.ID?
    let spawnAnimalLocomotion: AnimalLocomotion
    let selectedObjectAnimalLocomotion: AnimalLocomotion?
    let selectedContentType: PlacementContentType
    let selectedModelID: PlaceableUSDZModel.ID?
    @Binding var placedObjectSelection: PlacedObjectSelection?
    @Binding var selectedObjectElevationMeters: Float
    @Binding var isAdjustingObjectElevation: Bool
    @Binding var placementStatus: ARPlacementStatus
    @Binding var objectCount: Int
    @Binding var undoAvailable: Bool
    let command: NewARSceneCommand?
    let isAppSceneActive: Bool
    let isImmersive: Bool
    let onExitImmersive: () -> Void
    let onPencilTargetHovered: () -> Void
    let onPencilTargetMissing: () -> Void
    let onPencilRotationCompleted: () -> Void
    let onPhotoCaptured: (Result<UIImage, Error>) -> Void
    let onReadinessChanged: (ARTrackingReadiness) -> Void
    let onSessionInterrupted: () -> Void
    let feedback: any ARPlacementFeedbackProviding

    func makeCoordinator() -> NewARSceneController {
        NewARSceneController(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalLocomotion: spawnAnimalLocomotion,
            selectedContentType: selectedContentType,
            selectedModelID: selectedModelID,
            feedback: feedback,
            onSelectionChanged: updateSelection,
            onPlacementStatusChanged: updateStatus,
            onObjectCountChanged: updateObjectCount,
            onUndoAvailabilityChanged: updateUndoAvailability,
            onExitImmersive: onExitImmersive,
            onPencilTargetHovered: onPencilTargetHovered,
            onPencilTargetMissing: onPencilTargetMissing,
            onPencilRotationCompleted: onPencilRotationCompleted,
            onPhotoCaptured: onPhotoCaptured,
            onReadinessChanged: deliverReadinessUpdate,
            onSessionInterrupted: deliverSessionInterruption
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
        controller.selectedAnimalLocomotion = spawnAnimalLocomotion
        controller.selectedContentType = selectedContentType
        controller.selectedModelID = selectedModelID
        controller.onSelectionChanged = updateSelection
        controller.onPlacementStatusChanged = updateStatus
        controller.onObjectCountChanged = updateObjectCount
        controller.onUndoAvailabilityChanged = updateUndoAvailability
        controller.onExitImmersive = onExitImmersive
        controller.onPencilTargetHovered = onPencilTargetHovered
        controller.onPencilTargetMissing = onPencilTargetMissing
        controller.onPencilRotationCompleted = onPencilRotationCompleted
        controller.onPhotoCaptured = onPhotoCaptured
        controller.onReadinessChanged = deliverReadinessUpdate
        controller.onSessionInterrupted = deliverSessionInterruption
        controller.setAppSceneActive(isAppSceneActive)
        controller.setImmersive(isImmersive)

        if let selectedObjectAnimalLocomotion,
           controller.placedObjectSelection?.animalLocomotion != selectedObjectAnimalLocomotion {
            controller.setSelectedObjectAnimalLocomotion(selectedObjectAnimalLocomotion)
        }

        if let selectedObjectID = placedObjectSelection?.objectID {
            controller.synchronizeSelectedObjectElevation(
                selectedObjectElevationMeters,
                for: selectedObjectID,
                isEditing: isAdjustingObjectElevation
            )
        }

        if let command, controller.handledCommand != command {
            controller.handledCommand = command
            controller.handle(command)
        }
    }

    static func dismantleUIView(_ arView: ARView, coordinator: NewARSceneController) {
        coordinator.tearDown(arView)
    }

    private func updateSelection(_ selection: PlacedObjectSelection?) {
        Task { @MainActor in
            if placedObjectSelection?.objectID != selection?.objectID {
                isAdjustingObjectElevation = false
            }
            if placedObjectSelection != selection {
                placedObjectSelection = selection
            }
            if let selection,
               selectedObjectElevationMeters != selection.elevationMeters {
                selectedObjectElevationMeters = selection.elevationMeters
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

    private func deliverReadinessUpdate(_ readiness: ARTrackingReadiness) {
        Task { @MainActor in
            onReadinessChanged(readiness)
        }
    }

    private func deliverSessionInterruption() {
        Task { @MainActor in
            onSessionInterrupted()
        }
    }
}

private struct PencilRotationSession {
    let object: any PlacedSceneObject
    let initialOrientation: simd_quatf
    var lastRollAngle: Float
    var accumulatedAngle: Float = 0
}

@MainActor
final class NewARSceneController: NSObject, SceneEditing, @preconcurrency ARSessionDelegate {
    private static let signposter = OSSignposter(
        subsystem: "com.DirouDough.AniMagic",
        category: "AR Doodle Placement"
    )

    var cutoutAssets: [CutoutAsset] {
        get { sceneEditor.cutoutAssets }
        set {
            let removedObjectIDs = sceneEditor.updateCutoutAssets(newValue)
            if let pencilRotationSession,
               removedObjectIDs.contains(pencilRotationSession.object.id) {
                cancelPencilRotation()
            }
            if !removedObjectIDs.isEmpty {
                onObjectCountChanged?(sceneEditor.objectCount)
            }

            let availableAssetIDs = Set(newValue.map(\.id))
            if let pendingCutout = pendingDeletion?.object as? PlacedCutout,
               !availableAssetIDs.contains(pendingCutout.cutoutAssetID) {
                pendingDeletion = nil
                onUndoAvailabilityChanged?(false)
            }
            scheduleSelectedDoodlePreparation()
        }
    }
    var selectedCutoutID: CutoutAsset.ID? {
        get { sceneEditor.selectedCutoutID }
        set {
            guard sceneEditor.selectedCutoutID != newValue else { return }
            sceneEditor.selectedCutoutID = newValue
            preparedCutoutID = nil
            scheduleSelectedDoodlePreparation()
        }
    }
    var selectedAnimalLocomotion: AnimalLocomotion {
        get { sceneEditor.selectedAnimalLocomotion }
        set { sceneEditor.selectedAnimalLocomotion = newValue }
    }
    var selectedContentType: PlacementContentType {
        get { sceneEditor.selectedContentType }
        set {
            guard sceneEditor.selectedContentType != newValue else { return }
            sceneEditor.selectedContentType = newValue
            scheduleSelectedDoodlePreparation()
        }
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
    private var pencilInteractionAdapter: ApplePencilARInteractionAdapter?
    private var selectionGroundIndicator: Entity?
    private var heightGuide: Entity?
    private var elevationAdjustmentObjectID: UUID?
    private weak var pencilHoverTarget: (any PlacedSceneObject)?
    private var pencilRotationSession: PencilRotationSession?
    private var pendingDeletion: DeletedSceneObject?
    private var planeAnchors: [UUID: AnchorEntity] = [:]
    private var focusIndicator: Entity?
    private var focusAnchor: AnchorEntity?
    private var lightingAnchor: AnchorEntity?
    private var statusResetTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var preparationGeneration = 0
    private var preparingCutoutID: CutoutAsset.ID?
    private var preparedCutoutID: CutoutAsset.ID?
    private var isTargetAcquired = false
    private var isTrackingNormal = false
    private var isSessionInterrupted = false
    private var isAppSceneActive = true
    private var needsTrackingStateRefresh = false
    private var isTearingDown = false
    private var hasProvidedSurfaceReadyFeedback = false
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
    var onPencilTargetHovered: (() -> Void)?
    var onPencilTargetMissing: (() -> Void)?
    var onPencilRotationCompleted: (() -> Void)?
    var onPhotoCaptured: ((Result<UIImage, Error>) -> Void)?
    var onReadinessChanged: ((ARTrackingReadiness) -> Void)?
    var onSessionInterrupted: (() -> Void)?
    private(set) var placementStatus: ARPlacementStatus = .searching

    var selectedObject: (any PlacedSceneObject)? { sceneEditor.selectedObject }
    var placedObjectSelection: PlacedObjectSelection? { sceneEditor.placedObjectSelection }
    var isShowingImmersiveUI: Bool { isImmersive }
    var isPencilRotating: Bool { pencilRotationSession != nil }
    var isInteractionReady: Bool {
        isTrackingNormal && isTargetAcquired && !isSessionInterrupted && isAppSceneActive
    }

    private var isPlacementReady: Bool {
        guard isInteractionReady else { return false }
        switch selectedContentType {
        case .doodle:
            return selectedCutoutID != nil && preparedCutoutID == selectedCutoutID
        case .model:
            return true
        }
    }

    init(
        cutoutAssets: [CutoutAsset],
        selectedCutoutID: CutoutAsset.ID?,
        selectedAnimalLocomotion: AnimalLocomotion,
        selectedContentType: PlacementContentType,
        selectedModelID: PlaceableUSDZModel.ID?,
        feedback: any ARPlacementFeedbackProviding,
        onSelectionChanged: ((PlacedObjectSelection?) -> Void)? = nil,
        onPlacementStatusChanged: ((ARPlacementStatus) -> Void)? = nil,
        onObjectCountChanged: ((Int) -> Void)? = nil,
        onUndoAvailabilityChanged: ((Bool) -> Void)? = nil,
        onExitImmersive: (() -> Void)? = nil,
        onPencilTargetHovered: (() -> Void)? = nil,
        onPencilTargetMissing: (() -> Void)? = nil,
        onPencilRotationCompleted: (() -> Void)? = nil,
        onPhotoCaptured: ((Result<UIImage, Error>) -> Void)? = nil,
        onReadinessChanged: ((ARTrackingReadiness) -> Void)? = nil,
        onSessionInterrupted: (() -> Void)? = nil
    ) {
        sceneEditor = CutoutSceneEditor(
            cutoutAssets: cutoutAssets,
            selectedCutoutID: selectedCutoutID,
            selectedAnimalLocomotion: selectedAnimalLocomotion,
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
        self.onPencilTargetHovered = onPencilTargetHovered
        self.onPencilTargetMissing = onPencilTargetMissing
        self.onPencilRotationCompleted = onPencilRotationCompleted
        self.onPhotoCaptured = onPhotoCaptured
        self.onReadinessChanged = onReadinessChanged
        self.onSessionInterrupted = onSessionInterrupted
        super.init()

        sceneEditor.onSelectionChanged = { [weak self] selection in
            guard let self else { return }
            if selection?.objectID != self.elevationAdjustmentObjectID {
                self.elevationAdjustmentObjectID = nil
            }
            self.updateSelectionIndicator(for: selection)
            self.updateFocusVisibility()
            self.onSelectionChanged?(selection)
        }
        sceneEditor.onPlacementResult = { [weak self] result in
            self?.handlePlacementResult(result)
        }
    }

    func runSession(on arView: ARView) {
        isTearingDown = false
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

        setupLighting(in: arView)
        setupFocusIndicator(in: arView)
        let configuration = makeWorldTrackingConfiguration(for: arView)
        arView.session.delegate = self
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arView.renderOptions.insert(.disableGroundingShadows)
        arView.renderOptions.insert(.disableDepthOfField)

        let adapter = NewARViewInteractionAdapter(controller: self, feedback: feedback)
        adapter.attach(to: arView)
        interactionAdapter = adapter
        let pencilAdapter = ApplePencilARInteractionAdapter(controller: self)
        pencilAdapter.attach(to: arView)
        pencilInteractionAdapter = pencilAdapter
        updateStatus(.searching)
        onObjectCountChanged?(0)
        notifyReadinessChanged()
        scheduleSelectedDoodlePreparation()
    }

    private func setupLighting(in arView: ARView) {
        cleanupLighting()

        let anchor = AnchorEntity(.camera)
        addDirectionalLight(
            color: UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1.0),
            intensity: 1_000,
            position: [-1.0, 1.4, 0.8],
            to: anchor
        )
        addDirectionalLight(
            color: UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0),
            intensity: 1_000,
            position: [1.2, 0.7, 0.6],
            to: anchor
        )
        arView.scene.addAnchor(anchor)
        lightingAnchor = anchor
    }

    private func addDirectionalLight(
        color: UIColor,
        intensity: Float,
        position: SIMD3<Float>,
        to anchor: AnchorEntity
    ) {
        let light = Entity()
        var component = DirectionalLightComponent()
        component.color = color
        component.intensity = intensity
        light.components.set(component)
        anchor.addChild(light)
        light.look(at: [0, 0, -1], from: position, relativeTo: anchor)
    }

    func cleanupLighting() {
        guard let lightingAnchor else { return }
        arView?.scene.removeAnchor(lightingAnchor)
        self.lightingAnchor = nil
    }

    func handle(_ command: NewARSceneCommand) {
        switch command {
        case .place:
            guard isPlacementReady else { return }
            placeAtFocus()
        case .clearSelection:
            guard isInteractionReady else { return }
            clearSelection()
        case .delete:
            guard isInteractionReady else { return }
            cancelPencilRotation()
            pendingDeletion = deleteSelectedObject()
            let hasUndo = pendingDeletion != nil
            if hasUndo { feedback.warning() }
            onUndoAvailabilityChanged?(hasUndo)
            onObjectCountChanged?(sceneEditor.objectCount)
        case .flipFacing:
            guard isInteractionReady else { return }
            flipSelectedObjectAnimalFacing()
        case .undoDelete:
            guard isInteractionReady else { return }
            guard let pendingDeletion else { return }
            restoreDeletedObject(pendingDeletion)
            self.pendingDeletion = nil
            feedback.selectionChanged()
            onUndoAvailabilityChanged?(false)
            onObjectCountChanged?(sceneEditor.objectCount)
        case .discardUndo:
            pendingDeletion = nil
            onUndoAvailabilityChanged?(false)
        case .cancelPencilInteraction:
            cancelPencilRotation()
        case .capturePhoto:
            capturePhoto()
        }
    }

    private func capturePhoto() {
        guard let arView else {
            onPhotoCaptured?(.failure(ARPhotoCaptureError.viewUnavailable))
            return
        }

        arView.snapshot(saveToHDR: false) { [weak self] image in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let image else {
                    self.onPhotoCaptured?(.failure(ARPhotoCaptureError.snapshotFailed))
                    return
                }
                self.onPhotoCaptured?(.success(image))
            }
        }
    }

    private func makeWorldTrackingConfiguration(for arView: ARView) -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        configureOcclusion(on: arView, with: configuration)
        return configuration
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
                notifyReadinessChanged()
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
            if !hasProvidedSurfaceReadyFeedback {
                hasProvidedSurfaceReadyFeedback = true
                feedback.selectionChanged()
            }
            updateStatusIfScanning(.ready)
            notifyReadinessChanged()
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
        notifyReadinessChanged()
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

    func sessionWasInterrupted(_ session: ARSession) {
        isSessionInterrupted = true
        invalidateTrackingReadiness()
        onSessionInterrupted?()
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        isSessionInterrupted = false
        updateStatus(.limited("Point your device back at the original area and move slowly."))
        refreshTrackingState(from: session.currentFrame?.camera)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard needsTrackingStateRefresh,
              isAppSceneActive,
              !isSessionInterrupted else { return }
        applyTrackingState(frame.camera)
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
        guard isPlacementReady,
              placedObjectSelection == nil,
              isTargetAcquired,
              let targetTransform = lastValidTransform,
              let targetNormal = lastValidNormal else {
            updateStatus(.failed("Move the reticle onto a floor or table first."))
            feedback.warning()
            return
        }

        let signpostState = Self.signposter.beginInterval("Place Doodle at Focus")
        defer { Self.signposter.endInterval("Place Doodle at Focus", signpostState) }
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
        guard isInteractionReady else { return false }
        let previousID = placedObjectSelection?.objectID
        let handled = sceneEditor.handleTap(on: entity)
        if handled, placedObjectSelection?.objectID != previousID {
            feedback.selectionChanged()
        }
        return handled
    }

    func setPencilHoverTarget(at point: CGPoint) {
        guard isInteractionReady, !isPencilRotating, let arView else { return }
        let entity = arView.hitTest(point, query: .nearest, mask: .interactable).first?.entity
        let target = sceneEditor.object(containing: entity)
        guard target?.id != pencilHoverTarget?.id else { return }

        removePencilHoverIndicator()
        pencilHoverTarget = target
        guard let target else { return }

        let bounds = target.interactionRoot.visualBounds(relativeTo: target.interactionRoot)
        let radius = max(max(bounds.extents.x, bounds.extents.z) * 0.72, 0.14)
        let indicator = PencilHoverIndicatorFactory.make(radius: radius)
        target.interactionRoot.addChild(indicator)
        if !UIAccessibility.isReduceMotionEnabled {
            indicator.scale = SIMD3(repeating: 0.9)
            var targetTransform = indicator.transform
            targetTransform.scale = .one
            indicator.move(
                to: targetTransform,
                relativeTo: target.interactionRoot,
                duration: 0.16,
                timingFunction: .easeOut
            )
        }
        onPencilTargetHovered?()
    }

    func clearPencilHoverTarget() {
        guard !isPencilRotating else { return }
        removePencilHoverIndicator()
        pencilHoverTarget = nil
    }

    func beginPencilRotation(at point: CGPoint?, rollAngle: Float) {
        guard isInteractionReady, pencilRotationSession == nil else { return }
        if let point {
            setPencilHoverTarget(at: point)
        }
        guard let object = pencilHoverTarget else {
            feedback.warning()
            onPencilTargetMissing?()
            return
        }

        interactionAdapter?.setPencilInteractionActive(true)
        removePencilHoverIndicator()
        pencilHoverTarget = nil
        sceneEditor.selectObject(withID: object.id)
        object.setInteractionPaused(true)
        pencilRotationSession = PencilRotationSession(
            object: object,
            initialOrientation: object.interactionRoot.orientation(relativeTo: nil),
            lastRollAngle: rollAngle
        )
        addPencilRotationIndicator(to: object)
        feedback.pencilTargetAcquired()
    }

    func updatePencilRotation(rollAngle: Float) {
        guard isInteractionReady, var session = pencilRotationSession else { return }
        var delta = rollAngle - session.lastRollAngle
        if delta > .pi {
            delta -= 2 * .pi
        } else if delta < -.pi {
            delta += 2 * .pi
        }
        session.accumulatedAngle += delta
        session.lastRollAngle = rollAngle
        let axis = simd_normalize(session.object.supportSurfaceNormal)
        let rotation = simd_quatf(angle: -session.accumulatedAngle, axis: axis)
        session.object.interactionRoot.setOrientation(
            rotation * session.initialOrientation,
            relativeTo: nil
        )
        pencilRotationSession = session
    }

    func commitPencilRotation() {
        guard isInteractionReady, let session = pencilRotationSession else { return }
        finishPencilRotation(session: session, restoringOrientation: false)
        feedback.pencilRotationCommitted()
        onPencilRotationCompleted?()
    }

    func cancelPencilRotation() {
        guard let session = pencilRotationSession else {
            interactionAdapter?.setPencilInteractionActive(false)
            return
        }
        finishPencilRotation(session: session, restoringOrientation: true)
    }

    private func finishPencilRotation(
        session: PencilRotationSession,
        restoringOrientation: Bool
    ) {
        if restoringOrientation {
            session.object.interactionRoot.setOrientation(session.initialOrientation, relativeTo: nil)
        }
        session.object.interactionRoot.findEntity(named: "pencil_rotation_indicator")?.removeFromParent()
        session.object.setInteractionPaused(false)
        pencilRotationSession = nil
        interactionAdapter?.setPencilInteractionActive(false)
    }

    private func addPencilRotationIndicator(to object: any PlacedSceneObject) {
        object.interactionRoot.findEntity(named: "pencil_rotation_indicator")?.removeFromParent()
        let bounds = object.interactionRoot.visualBounds(relativeTo: object.interactionRoot)
        let radius = max(max(bounds.extents.x, bounds.extents.z) * 0.82, 0.16)
        object.interactionRoot.addChild(PencilRotationIndicatorFactory.make(radius: radius))
    }

    private func removePencilHoverIndicator() {
        pencilHoverTarget?.interactionRoot
            .findEntity(named: "pencil_hover_indicator")?
            .removeFromParent()
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
        guard let ring = selectionGroundIndicator else { return }
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
        selectionGroundIndicator?.removeFromParent()
        selectionGroundIndicator = nil
        heightGuide = nil

        guard selection != nil, let selectedObject else {
            return
        }

        let bounds = selectedObject.interactionRoot.visualBounds(relativeTo: selectedObject.interactionRoot)
        let radius = max(max(bounds.extents.x, bounds.extents.z) * 0.65, 0.12)
        let ring = SelectionRingFactory.make(radius: radius)
        let guide = HeightGuideFactory.make()
        ring.addChild(guide)
        selectedObject.anchor.addChild(ring)
        selectionGroundIndicator = ring
        heightGuide = guide
        updateSelectionGroundReference()

        guard !UIAccessibility.isReduceMotionEnabled else { return }
        ring.scale = [0.84, 0.84, 0.84]
        var target = ring.transform
        target.scale = .one
        ring.move(to: target, relativeTo: selectedObject.anchor, duration: 0.22, timingFunction: .easeOut)
    }

    func updateSelectionGroundReference() {
        guard let selectedObject, let selectionGroundIndicator else { return }
        let objectPosition = selectedObject.interactionRoot.position(relativeTo: selectedObject.anchor)
        selectionGroundIndicator.position = [objectPosition.x, 0, objectPosition.z]

        let elevation = max(selectedObject.elevationMeters, 0)
        heightGuide?.position = [0, elevation / 2, 0]
        heightGuide?.scale = [1, max(elevation, 0.001), 1]
    }

    func synchronizeSelectedObjectElevation(
        _ elevationMeters: Float,
        for objectID: UUID,
        isEditing: Bool
    ) {
        guard isInteractionReady, selectedObject?.id == objectID else { return }

        if isEditing {
            if elevationAdjustmentObjectID != objectID {
                sceneEditor.beginSelectedObjectElevationAdjustment(for: objectID)
                elevationAdjustmentObjectID = objectID
            }
            sceneEditor.setSelectedObjectElevationMeters(elevationMeters, for: objectID)
        } else {
            sceneEditor.setSelectedObjectElevationMeters(elevationMeters, for: objectID)
            if elevationAdjustmentObjectID == objectID {
                sceneEditor.endSelectedObjectElevationAdjustment(for: objectID)
                elevationAdjustmentObjectID = nil
            }
        }

        updateSelectionGroundReference()
        heightGuide?.components.set(
            OpacityComponent(opacity: isEditing && elevationMeters > 0 ? 0.72 : 0)
        )
    }

    func beginSelectedObjectElevationAdjustment(for objectID: UUID) {
        guard isInteractionReady else { return }
        sceneEditor.beginSelectedObjectElevationAdjustment(for: objectID)
    }

    func setSelectedObjectElevationMeters(_ elevationMeters: Float, for objectID: UUID) {
        guard isInteractionReady else { return }
        sceneEditor.setSelectedObjectElevationMeters(elevationMeters, for: objectID)
        updateSelectionGroundReference()
    }

    func endSelectedObjectElevationAdjustment(for objectID: UUID) {
        guard isInteractionReady else { return }
        sceneEditor.endSelectedObjectElevationAdjustment(for: objectID)
    }

    func setSelectedObjectAnimalLocomotion(_ locomotion: AnimalLocomotion) {
        guard isInteractionReady else { return }
        sceneEditor.setSelectedObjectAnimalLocomotion(locomotion)
    }

    func flipSelectedObjectAnimalFacing() {
        guard isInteractionReady else { return }
        sceneEditor.flipSelectedObjectAnimalFacing()
    }

    @discardableResult
    func deleteSelectedObject() -> DeletedSceneObject? {
        guard isInteractionReady else { return nil }
        return sceneEditor.deleteSelectedObject()
    }

    func restoreDeletedObject(_ deletedObject: DeletedSceneObject) {
        guard isInteractionReady else { return }
        sceneEditor.restoreDeletedObject(deletedObject)
    }

    func clearSelection() {
        cancelPencilRotation()
        sceneEditor.clearSelection()
    }

    func stopAnimationLoop() {
        statusResetTask?.cancel()
        statusResetTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        setSelectionIndicatorDragging(false)
        pencilInteractionAdapter?.detach()
        pencilInteractionAdapter = nil
        interactionAdapter?.detach()
        interactionAdapter = nil
        pendingDeletion = nil
    }

    func tearDown(_ arView: ARView) {
        guard !isTearingDown else { return }
        isTearingDown = true
        arView.session.delegate = nil
        clearCallbacks()
        stopAnimationLoop()
        cleanupLighting()
        cleanupFocusIndicator()
        cleanupPlaneAnchors()
        arView.session.pause()
        sceneEditor.arView = nil
        self.arView = nil
    }

    private func clearCallbacks() {
        onPlacementStatusChanged = nil
        onSelectionChanged = nil
        onObjectCountChanged = nil
        onUndoAvailabilityChanged = nil
        onExitImmersive = nil
        onPencilTargetHovered = nil
        onPencilTargetMissing = nil
        onPencilRotationCompleted = nil
        onPhotoCaptured = nil
        onReadinessChanged = nil
        onSessionInterrupted = nil
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
        case .searching, .ready, .loading, .placed:
            updateStatus(needsSelectedDoodlePreparation ? .loading("Preparing doodle…") : newStatus)
        default:
            break
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        applyTrackingState(camera)
    }

    private func applyTrackingState(_ camera: ARCamera) {
        needsTrackingStateRefresh = false
        switch camera.trackingState {
        case .normal:
            isTrackingNormal = true
            isSessionInterrupted = false
            updateStatus(
                needsSelectedDoodlePreparation
                    ? .loading("Preparing doodle…")
                    : (isTargetAcquired ? .ready : .searching)
            )
        case .limited(let reason):
            isTrackingNormal = false
            updateStatus(.limited(reason.trackingMessage))
        case .notAvailable:
            isTrackingNormal = false
            updateStatus(.limited("Camera tracking is unavailable."))
            requestExitImmersive()
        }
        if !isInteractionReady {
            cancelActiveInteractions()
        }
        notifyReadinessChanged()
    }

    private func refreshTrackingState(from camera: ARCamera?) {
        guard let camera else {
            needsTrackingStateRefresh = true
            notifyReadinessChanged()
            return
        }
        applyTrackingState(camera)
    }

    private var needsSelectedDoodlePreparation: Bool {
        selectedContentType == .doodle
            && selectedCutoutID != nil
            && preparedCutoutID != selectedCutoutID
    }

    private func scheduleSelectedDoodlePreparation() {
        guard arView != nil else { return }

        guard selectedContentType == .doodle, let selectedCutoutID else {
            preparationGeneration += 1
            preparationTask?.cancel()
            preparationTask = nil
            preparingCutoutID = nil
            if case .loading = placementStatus, isTrackingNormal {
                updateStatus(isTargetAcquired ? .ready : .searching)
            }
            return
        }
        guard preparedCutoutID != selectedCutoutID,
              preparingCutoutID != selectedCutoutID else { return }

        preparationGeneration += 1
        let generation = preparationGeneration
        preparationTask?.cancel()
        preparingCutoutID = selectedCutoutID
        updateStatus(.loading("Preparing doodle…"))

        preparationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled,
                  let self,
                  self.preparationGeneration == generation,
                  self.selectedContentType == .doodle,
                  self.selectedCutoutID == selectedCutoutID else { return }

            do {
                let preparedID = try self.sceneEditor.prepareSelectedCutout()
                guard self.preparationGeneration == generation,
                      self.selectedCutoutID == preparedID else { return }
                self.preparedCutoutID = preparedID
                self.preparingCutoutID = nil
                self.preparationTask = nil
                if self.isTrackingNormal {
                    self.updateStatus(self.isTargetAcquired ? .ready : .searching)
                }
            } catch {
                guard self.preparationGeneration == generation else { return }
                self.preparingCutoutID = nil
                self.preparationTask = nil
                self.updateStatus(.failed("This doodle could not be prepared."))
                self.statusResetTask?.cancel()
                self.statusResetTask = nil
            }
        }
    }

    private func notifyReadinessChanged() {
        guard !isTearingDown else { return }
        onReadinessChanged?(ARTrackingReadiness(
            isTrackingNormal: isTrackingNormal && !isSessionInterrupted && isAppSceneActive,
            hasSurface: isTargetAcquired
        ))
    }

    func setAppSceneActive(_ isActive: Bool) {
        guard isAppSceneActive != isActive else { return }
        isAppSceneActive = isActive
        if isActive {
            refreshTrackingState(from: arView?.session.currentFrame?.camera)
        } else {
            invalidateTrackingReadiness()
        }
    }

    private func invalidateTrackingReadiness() {
        isTrackingNormal = false
        isTargetAcquired = false
        lastValidTransform = nil
        lastValidNormal = nil
        focusIndicator?.isEnabled = false
        needsTrackingStateRefresh = true
        cancelActiveInteractions()
        notifyReadinessChanged()
    }

    private func cancelActiveInteractions() {
        cancelPencilRotation()
        clearPencilHoverTarget()
        interactionAdapter?.cancelActiveInteractions()
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

struct HeightGuideFactory {
    static func make() -> Entity {
        let guide = Entity()
        guide.name = "height_guide"

        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(Color.Palette.b200))
        let model = ModelEntity(
            mesh: .generateCylinder(height: 1, radius: 0.004),
            materials: [material]
        )
        guide.addChild(model)
        guide.components.set(OpacityComponent(opacity: 0))
        return guide
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
    private var previousScaleForDetents: Float?
    private var lastRotationDetent = 0
    private var isPencilInteractionActive = false

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

    func setPencilInteractionActive(_ isActive: Bool) {
        guard isPencilInteractionActive != isActive else { return }
        if isActive {
            recognizers.forEach {
                $0.isEnabled = false
                $0.isEnabled = true
            }
            activeManipulations.removeAll()
            resetDragState()
            controller?.setSelectionIndicatorDragging(false)
            controller?.selectedObject?.setInteractionPaused(false)
        }
        isPencilInteractionActive = isActive
    }

    func cancelActiveInteractions() {
        recognizers.forEach {
            $0.isEnabled = false
            $0.isEnabled = true
        }
        activeManipulations.removeAll()
        resetDragState()
        controller?.setSelectionIndicatorDragging(false)
        controller?.selectedObject?.setInteractionPaused(false)
        isPencilInteractionActive = false
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard !isPencilInteractionActive else { return }
        guard let arView, let controller, controller.isInteractionReady else { return }
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
        guard !isPencilInteractionActive else { return }
        guard let arView, let controller, controller.isInteractionReady else { return }
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
            controller.updateSelectionGroundReference()
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
            controller.updateSelectionGroundReference()
        case .ended, .cancelled, .failed:
            end(.translation)
            resetDragState()
            controller.setSelectionIndicatorDragging(false)
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard !isPencilInteractionActive else { return }
        guard controller?.isInteractionReady == true,
              let selectedObject = controller?.selectedObject else { return }
        switch recognizer.state {
        case .began:
            initialScale = selectedObject.interactionRoot.scale
            didReachLowerScaleBound = false
            didReachUpperScaleBound = false
            previousScaleForDetents = initialScale.x
            begin(.scale)
        case .changed:
            let rawScale = initialScale.x * Float(recognizer.scale)
            let displayedScale = rubberBandedScale(rawScale)
            selectedObject.interactionRoot.scale = SIMD3(repeating: displayedScale)
            provideBoundaryFeedback(for: rawScale)
            provideScaleDetentFeedback(for: rawScale)
        case .ended, .cancelled, .failed:
            let clamped = min(max(selectedObject.interactionRoot.scale.x, 0.25), 4)
            selectedObject.interactionRoot.scale = SIMD3(repeating: clamped)
            previousScaleForDetents = nil
            end(.scale)
        default:
            break
        }
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard !isPencilInteractionActive else { return }
        guard controller?.isInteractionReady == true,
              let selectedObject = controller?.selectedObject else { return }
        switch recognizer.state {
        case .began:
            initialOrientation = selectedObject.interactionRoot.orientation(relativeTo: nil)
            lastRotationDetent = 0
            begin(.rotation)
        case .changed:
            let axis = simd_normalize(selectedObject.supportSurfaceNormal)
            let rotation = simd_quatf(angle: -Float(recognizer.rotation), axis: axis)
            selectedObject.interactionRoot.setOrientation(rotation * initialOrientation, relativeTo: nil)
            provideRotationDetentFeedback(for: Float(recognizer.rotation))
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

    private func provideScaleDetentFeedback(for rawScale: Float) {
        guard let previousScaleForDetents else {
            self.previousScaleForDetents = rawScale
            return
        }

        let milestones: [Float] = [0.5, 1, 2]
        let crossedMilestone = milestones.contains { milestone in
            (previousScaleForDetents < milestone && rawScale >= milestone)
                || (previousScaleForDetents > milestone && rawScale <= milestone)
        }
        if crossedMilestone {
            feedback.detent()
        }
        self.previousScaleForDetents = rawScale
    }

    private func provideRotationDetentFeedback(for rotation: Float) {
        let radiansPerDetent = Float.pi / 12
        let detent = Int((rotation / radiansPerDetent).rounded(.towardZero))
        guard detent != lastRotationDetent else { return }
        lastRotationDetent = detent
        feedback.detent()
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

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        controller?.isInteractionReady == true && !isPencilInteractionActive
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let status: ARPlacementStatus

    var body: some View {
        ZStack {
            Color.Token.Background.primary
                .opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                iconView(icon: iconName, secondaryIcon: "hand.tap.fill")
                outlinedText(text: title)

                Text(detail)
                    .font(.custom("Belanosima-Regular", size: 22, relativeTo: .body))
                    .foregroundStyle(Color(Color.Palette.n70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .id(title)
            .transition(.opacity)
        }
        .animation(reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection, value: title)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }

    private var title: String {
        switch status {
        case .limited:
            "Move your phone to start"
        case .loading:
            "Getting Your Creation Ready"
        case .failed:
            "Keep Looking for a Surface"
        case .searching, .ready, .placed:
            "Finding a Surface"
        }
    }

    private var detail: String {
        switch status {
        case .limited(let message), .loading(let message), .failed(let message):
            message
        case .searching, .ready, .placed:
            "Slowly point your device at a well-lit floor or table."
        }
    }

    private var iconName: String {
        if case .limited = status {
            return "iphone"
        }
        return "iphone.radiowaves.left.and.right"
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
                    .font(.custom("Belanosima-SemiBold", size: 40, relativeTo: .title))
                    .foregroundColor(.white)
                    .offset(
                        x: CGFloat(cos(Double(i) * .pi / 6)) * 6,
                        y: CGFloat(sin(Double(i) * .pi / 6)) * 6
                    )
            }
            Text(text)
                .font(.custom("Belanosima-SemiBold", size: 40, relativeTo: .title))
                .foregroundColor(Color(Color.Palette.n70))
        }
        .lineLimit(2)
        .minimumScaleFactor(0.75)
    }
}
