//
//  ARPlacementControls.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import QuickLookThumbnailing
import SwiftUI
import UIKit

/// Sleek floating HUD for contextual placement instructions
struct ARInstructionBanner: View {
    let contentType: PlacementContentType
    let spawnMode: SpawnMode
    let status: ARPlacementStatus

    private var title: String {
        switch status {
        case .searching: return "Scanning Surface"
        case .ready: return "Surface Found"
        case .loading: return "Loading Model"
        case .placed: return "Placed"
        case .limited, .failed: return "Scanning Surface"
        }
    }

    private var detail: String {
        switch status {
        case .loading(let message), .limited(let message), .failed(let message): return message
        default:
            return contentType == .model
                ? "Tap floor to place"
                : spawnMode == .plane ? "Tap floor to spawn" : "Tap anywhere to spawn"
        }
    }

    private var statusIcon: String {
        switch status {
        case .ready: return "checkmark.circle.fill"
        case .loading: return "hourglass"
        case .placed: return "checkmark.circle"
        default: return "viewfinder"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(status == .ready ? .green : .accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6)
    }
}

/// Compact segmented custom control for Content Type switching
struct PlacementContentTypePicker: View {
    @Binding var selection: PlacementContentType

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PlacementContentType.allCases) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = type
                    }
                } label: {
                    Text(type.title)
                        .font(.custom("Belanosima-SemiBold", size: 20, relativeTo: .headline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == type ? .white : AnimagicTheme.blue.opacity(0.7))
                        .background(
                            Capsule()
                                .fill(selection == type ? AnimagicTheme.blue : Color(Color.Palette.b50))
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(type.title)
                .accessibilityAddTraits(selection == type ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white))
        .overlay {
            Capsule()
                .strokeBorder(Color(Color.Palette.b50), lineWidth: 3)
        }
        .frame(maxWidth: 220)
    }
}

/// Lightweight message when doodle library is empty
struct EmptyDoodleLibraryMessage: View {
    var body: some View {
        Text("No cutouts yet. Open the Canvas to draw!")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
    }
}

/// Minimalist USDZ 3D Model picker carousel
struct USDZModelPicker: View {
    @Binding var selection: PlaceableUSDZModel.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PlaceableUSDZModel.all) { model in
                    Button {
                        selection = model.id
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: model.systemImageName)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(selection == model.id ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                .clipShape(Circle())
                            Text(model.title)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selection == model.id ? Color.accentColor : Color.primary)
                        .frame(width: 72)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

/// Compact cutout (doodle) carousel picker
struct CutoutPicker: View {
    let assets: [CutoutAsset]
    @Binding var selection: CutoutAsset.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(assets) { asset in
                    Button {
                        selection = asset.id
                    } label: {
                        Image(uiImage: asset.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .padding(4)
                            .background(selection == asset.id ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                            .overlay {
                                Circle()
                                    .stroke(selection == asset.id ? Color.accentColor : Color.clear, lineWidth: 2)
                            }
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

/// Floating action capsule when an existing placed object is highlighted
struct SelectedObjectToolbar: View {
    let title: String
    let onDelete: () -> Void

    var body: some View {
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

// MARK: - Magic Lens controls

struct NewARStatusPill: View {
    let status: ARPlacementStatus

    private var content: (
        title: String,
        detail: String?,
        icon: String,
        accentColor: Color
    ) {
        switch status {
        case .searching:
            ("Finding a surface", "Move slowly over a floor or table", "viewfinder", Color.Palette.y400)
        case .ready:
            ("Ready to place", nil, "checkmark.circle.fill", Color.Palette.g400)
        case .loading(let message):
            ("Getting it ready", message, "hourglass", Color.Palette.y400)
        case .placed:
            ("Magic placed!", nil, "sparkles", Color.Palette.g400)
        case .limited(let message):
            ("Tracking paused", message, "exclamationmark.triangle.fill", Color.Palette.o400)
        case .failed(let message):
            ("Something went wrong", message, "exclamationmark.circle.fill", Color.Palette.r400)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: content.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(content.accentColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.custom("Belanosima-SemiBold", size: 17, relativeTo: .headline))
                if let detail = content.detail {
                    Text(detail)
                        .font(.custom("Belanosima-Regular", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.Palette.n60)
                        .lineLimit(2)
                }
            }
        }
        .foregroundStyle(Color.Palette.n70)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .arTransientSurface()
        .accessibilityElement(children: .combine)
    }
}

struct ARTransientHint: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.custom("Belanosima-SemiBold", size: 17, relativeTo: .headline))
            .lineLimit(2)
        .foregroundStyle(Color.Palette.n70)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .arTransientSurface()
        .fixedSize(horizontal: false, vertical: true)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct ARTransientSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.Palette.n70, lineWidth: 2)
            }
    }
}

private extension View {
    func arTransientSurface() -> some View {
        modifier(ARTransientSurfaceModifier())
    }
}

struct NewARObjectShelf: View {
    @Binding var contentType: PlacementContentType
    let cutoutAssets: [CutoutAsset]
    @Binding var selectedCutoutID: CutoutAsset.ID?
    @Binding var selectedModelID: PlaceableUSDZModel.ID?
    let canPlace: Bool
    let placeButtonTitle: String
    let onPlace: () -> Void
    let onSelectionFeedback: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                PlacementContentTypePicker(selection: $contentType)
                    .onChange(of: contentType) { _, _ in onSelectionFeedback() }

                Spacer(minLength: 8)

                Button(action: onPlace) {
                    Label(placeButtonTitle, systemImage: "sparkles")
                        .font(.callout.bold())
                        .foregroundStyle(canPlace ? .black : .secondary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background(canPlace ? Color.yellow : Color.secondary.opacity(0.13))
                        .clipShape(Capsule())
                }
                .buttonStyle(ARPressButtonStyle())
                .disabled(!canPlace)
                .accessibilityHint(canPlace ? "Places the selected object at the reticle" : placeButtonTitle)
            }

            Group {
                if contentType == .doodle {
                    doodleShelf
                } else {
                    modelShelf
                }
            }
            .frame(minHeight: 88)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
    }

    @ViewBuilder
    private var doodleShelf: some View {
        if cutoutAssets.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No doodles yet")
                        .font(.callout.bold())
                    Text("Choose 3D Models, or go back and make a doodle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cutoutAssets) { asset in
                        Button {
                            selectedCutoutID = asset.id
                            onSelectionFeedback()
                        } label: {
                            ARSelectionCard(
                                title: asset.resolvedDoodleLabel?.capitalized ?? "My Doodle",
                                isSelected: selectedCutoutID == asset.id
                            ) {
                                Image(uiImage: asset.image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                            }
                        }
                        .buttonStyle(ARPressButtonStyle())
                        .accessibilityLabel(asset.resolvedDoodleLabel?.capitalized ?? "Doodle")
                        .accessibilityAddTraits(selectedCutoutID == asset.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var modelShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlaceableUSDZModel.all) { model in
                    Button {
                        selectedModelID = model.id
                        onSelectionFeedback()
                    } label: {
                        ARSelectionCard(title: model.title, isSelected: selectedModelID == model.id) {
                            ARUSDZThumbnail(model: model)
                        }
                    }
                    .buttonStyle(ARPressButtonStyle())
                    .accessibilityLabel(model.title)
                    .accessibilityAddTraits(selectedModelID == model.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct NewAREditCard: View {
    let selection: PlacedObjectSelection
    @Binding var animalLocomotion: AnimalLocomotion
    @Binding var elevationMeters: Float
    let onElevationEditingChanged: (Bool) -> Void
    let onElevationGrounded: () -> Void
    let onElevationMaximumReached: () -> Void
    let onFlip: () -> Void
    let onDone: () -> Void
    let onDelete: () -> Void

    @State private var isMovementPickerExpanded = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Magic placed!")
                        .font(.custom("Belanosima-SemiBold", size: 24))
                        .foregroundStyle(Color.Palette.n70)
                    Text(selection.title)
                        .font(.custom("Belanosima-Regular", size: 20))
                        .foregroundStyle(Color.Palette.n60)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AnimagicIconButton(
                    icon: "checkmark",
                    backgroundColor: Color.Token.Button.success,
                    innerBorderColor: .black.opacity(0.2),
                    action: onDone
                )
                .accessibilityLabel("Done editing \(selection.title)")

                AnimagicIconButton(
                    icon: "trash.fill",
                    backgroundColor: Color(Color.Palette.r300),
                    innerBorderColor: .black.opacity(0.2),
                    action: onDelete
                )
                .accessibilityLabel("Delete \(selection.title)")
            }

            HStack(spacing: 12) {
                gestureHint(icon: "hand.draw.fill", title: "Drag to move")
                gestureHint(icon: "arrow.up.left.and.arrow.down.right", title: "Pinch to resize")
                gestureHint(icon: "rotate.3d", title: "Twist to turn")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.Palette.n10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.Palette.n20, lineWidth: 3)
                    }
            )

            ARHeightControl(
                elevationMeters: $elevationMeters,
                onEditingChanged: onElevationEditingChanged,
                onGrounded: onElevationGrounded,
                onMaximumReached: onElevationMaximumReached
            )
            .frame(height: 80)

            if selection.animalLocomotion != nil {
                VStack(spacing: 10) {
//                    Button(action: onFlip) {
//                        Label("Flip direction", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
//                            .font(.custom("Belanosima-SemiBold", size: 18))
//                    }
//                    .buttonStyle(.bordered)
//                    .accessibilityHint("Corrects which way the doodle faces and moves")

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isMovementPickerExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: animalLocomotion.systemImageName)
                            Text(animalLocomotion.title)
                            Spacer()
                            Image(systemName: isMovementPickerExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(.custom("Belanosima-SemiBold", size: 20))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 52)
                        .background(
                            Capsule()
                                .fill(Color.Token.Button.secondary)
                                .overlay {
                                    Capsule()
                                        .strokeBorder(.black.opacity(0.2), lineWidth: 4)
                                }
                        )
                        .padding(8)
                        .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.animagicPress)
                    .accessibilityLabel("Movement behavior, \(animalLocomotion.title)")

                    if isMovementPickerExpanded {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(AnimalLocomotion.allCases) { locomotion in
                                    ARMovementChoiceButton(
                                        locomotion: locomotion,
                                        isSelected: animalLocomotion == locomotion
                                    ) {
                                        animalLocomotion = locomotion
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            isMovementPickerExpanded = false
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.Token.Background.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.Palette.n70, lineWidth: 4)
                }
        )
        .shadow(color: Color.Palette.n70.opacity(0.18), radius: 14, y: 5)
    }

    private func gestureHint(icon: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
            Text(title)
                .font(.custom("Belanosima-Regular", size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.Palette.n70)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct ARHeightControl: View {
    private enum FeedbackBoundary {
        case grounded
        case maximum
    }

    @Binding var elevationMeters: Float
    let onEditingChanged: (Bool) -> Void
    let onGrounded: () -> Void
    let onMaximumReached: () -> Void

    @State private var isEditing = false
    @State private var feedbackBoundary: FeedbackBoundary?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("Height", systemImage: "arrow.up.and.down")
                    .font(.custom("Belanosima-SemiBold", size: 19))

                Spacer()

                Text(formattedElevation)
                    .font(.custom("Belanosima-SemiBold", size: 17))
                    .foregroundStyle(Color.Palette.b300)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                Image(systemName: "arrow.down.to.line")
                sliderTrack
                Image(systemName: "arrow.up.to.line")
            }
            .font(.system(size: 16, weight: .bold))
        }
        .foregroundStyle(Color.Palette.n70)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.Palette.n10)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.Palette.n20, lineWidth: 3)
                }
        )
        .accessibilityRepresentation {
            Slider(
                value: accessibilityBinding,
                in: ARObjectElevation.range,
                step: 0.05,
                onEditingChanged: handleEditingChanged
            ) {
                Text("Height")
            }
            .accessibilityValue(formattedElevation)
            .accessibilityHint("Adjusts how high the selected object floats above its surface")
        }
    }

    private var sliderTrack: some View {
        GeometryReader { geometry in
            let thumbDiameter: CGFloat = 32
            let usableWidth = max(geometry.size.width - thumbDiameter, 1)
            let progress = CGFloat(elevationMeters / ARObjectElevation.range.upperBound)
            let thumbOffset = usableWidth * min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.Palette.n20)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.Palette.n30, lineWidth: 3)
                    }
                    .frame(height: 16)

                Capsule()
                    .fill(Color.Palette.b200)
                    .frame(width: thumbOffset + thumbDiameter / 2, height: 16)

                Circle()
                    .fill(Color.Palette.b200)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.Palette.b400, lineWidth: 4)
                    }
                    .padding(4)
                    .background(Circle().fill(.white))
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .offset(x: thumbOffset)
                    .shadow(color: Color.Palette.n70.opacity(0.16), radius: 4, y: 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(sliderGesture(width: geometry.size.width, thumbDiameter: thumbDiameter))
        }
        .frame(minWidth: 180, minHeight: 44)
    }

    private var accessibilityBinding: Binding<Float> {
        Binding(
            get: { elevationMeters },
            set: { updateElevation(to: $0) }
        )
    }

    private func sliderGesture(width: CGFloat, thumbDiameter: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isEditing {
                    feedbackBoundary = boundary(for: elevationMeters)
                    handleEditingChanged(true)
                }

                let usableWidth = max(width - thumbDiameter, 1)
                let progress = min(max((value.location.x - thumbDiameter / 2) / usableWidth, 0), 1)
                updateElevation(to: Float(progress) * ARObjectElevation.range.upperBound)
            }
            .onEnded { _ in
                handleEditingChanged(false)
                feedbackBoundary = nil
            }
    }

    private func updateElevation(to proposedElevation: Float) {
        let clamped = min(
            max(proposedElevation, ARObjectElevation.range.lowerBound),
            ARObjectElevation.range.upperBound
        )
        let adjusted = clamped <= ARObjectElevation.groundingThreshold ? 0 : clamped
        elevationMeters = adjusted

        let newBoundary = boundary(for: adjusted)
        guard newBoundary != feedbackBoundary else { return }
        feedbackBoundary = newBoundary

        switch newBoundary {
        case .grounded:
            onGrounded()
        case .maximum:
            onMaximumReached()
        case nil:
            break
        }
    }

    private func handleEditingChanged(_ editing: Bool) {
        guard editing != isEditing else { return }
        isEditing = editing
        if editing {
            feedbackBoundary = boundary(for: elevationMeters)
        }
        onEditingChanged(editing)
    }

    private func boundary(for elevation: Float) -> FeedbackBoundary? {
        if elevation == 0 { return .grounded }
        if elevation >= ARObjectElevation.range.upperBound { return .maximum }
        return nil
    }

    private var formattedElevation: String {
        if elevationMeters == 0 {
            return "Grounded"
        }
        if elevationMeters < 1 {
            return "\(Int((elevationMeters * 100).rounded())) cm"
        }
        return elevationMeters.formatted(.number.precision(.fractionLength(1))) + " m"
    }
}

private struct ARMovementChoiceButton: View {
    let locomotion: AnimalLocomotion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: locomotion.systemImageName)
                    .font(.system(size: 22, weight: .bold))
                Text(locomotion.title)
                    .font(.custom("Belanosima-Regular", size: 15))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : Color.Palette.n70)
            .frame(width: 76, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.Token.Button.secondary : Color.Palette.n20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.black.opacity(0.2) : Color.Palette.n30,
                                lineWidth: 4
                            )
                    }
            )
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.animagicPress)
        .accessibilityLabel(locomotion.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ARDeleteUndoToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.Palette.r300)
            Text("Object deleted")
                .font(.custom("Belanosima-SemiBold", size: 17, relativeTo: .headline))

            Rectangle()
                .fill(Color.Palette.n20)
                .frame(width: 1, height: 22)

            Button(action: onUndo) {
                Text("Undo")
                    .font(.custom("Belanosima-SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(Color.Palette.b300)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.animagicPress)
            .accessibilityHint("Restores the deleted object")
        }
        .foregroundStyle(Color.Palette.n70)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .arTransientSurface()
        .accessibilityElement(children: .contain)
    }
}

struct ARSelectionCard<Preview: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let preview: Preview

    var body: some View {
        VStack(spacing: 4) {
            preview
                .frame(width: 100, height: 82)
            Text(title)
                .font(.caption2.bold())
                .lineLimit(1)
                .frame(maxWidth: 128)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: 140)
        .frame(minHeight: 128)
        .background(isSelected ? Color.yellow.opacity(0.28) : Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, .blue)
                    .padding(5)
            }
        }
    }
}

struct ARUSDZThumbnail: View {
    let model: PlaceableUSDZModel
    @State private var image: UIImage?
    @State private var didRequestImage = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: model.systemImageName)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.blue)
            }
        }
        .task(id: model.id) {
            requestThumbnailIfNeeded()
        }
    }

    private func requestThumbnailIfNeeded() {
        guard !didRequestImage else { return }
        didRequestImage = true
        if let cached = ARUSDZThumbnailCache.shared.image(for: model.id) {
            image = cached
            return
        }
        guard let url = Bundle.main.url(
            forResource: model.resourceName,
            withExtension: "usdz",
            subdirectory: model.resourceSubdirectory
        ) else { return }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 180, height: 140),
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let thumbnail = representation?.uiImage else { return }
            Task { @MainActor in
                ARUSDZThumbnailCache.shared.insert(thumbnail, for: model.id)
                image = thumbnail
            }
        }
    }
}

@MainActor
private final class ARUSDZThumbnailCache {
    static let shared = ARUSDZThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(for id: PlaceableUSDZModel.ID) -> UIImage? {
        cache.object(forKey: id.rawValue as NSString)
    }

    func insert(_ image: UIImage, for id: PlaceableUSDZModel.ID) {
        cache.setObject(image, forKey: id.rawValue as NSString)
    }
}

private struct ARPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct VerticalARObjectShelf: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Binding var contentType: PlacementContentType
    let cutoutAssets: [CutoutAsset]
    let titleForCutout: (CutoutAsset) -> String
    @Binding var selectedCutoutID: CutoutAsset.ID?
    @Binding var selectedModelID: PlaceableUSDZModel.ID?
    let shelfHeight: CGFloat
    let canPlace: Bool
    let placeButtonTitle: String
    let onCollapse: () -> Void
    let onPlace: () -> Void
    let onSelectionFeedback: () -> Void

    let columns = [
        GridItem(.adaptive(minimum: 112, maximum: 130), spacing: 12)
    ]

    private var shelfWidth: CGFloat {
        verticalSizeClass == .compact ? 340 : 400
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Collapse Button attached to the left edge
            Button(action: onCollapse) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color.blue))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
            }
            .padding(.trailing, -20)
            .zIndex(1) // Keep above the shelf
            
            let shelfShape = UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )

            VStack(spacing: 12) {
                PlacementContentTypePicker(selection: $contentType)
                    .onChange(of: contentType) { _, _ in onSelectionFeedback() }
                    .padding(.top, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if contentType == .doodle {
                            doodleShelf
                        } else {
                            modelShelf
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: shelfWidth, height: shelfHeight)
            .background(AnimagicTheme.yellow, in: shelfShape)
            .clipShape(shelfShape)
            .overlay {
                shelfShape
                    .strokeBorder(Color.white, lineWidth: 6) // Using white border to match reference
            }
            .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
        }
    }

    @ViewBuilder
    private var doodleShelf: some View {
        if cutoutAssets.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundStyle(.blue)
                    .font(.largeTitle)
                Text("No doodles yet")
                    .font(.callout.bold())
                Text("Choose 3D Models, or go back and make a doodle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cutoutAssets) { asset in
                    let title = titleForCutout(asset)
                    Button {
                        selectedCutoutID = asset.id
                        onSelectionFeedback()
                    } label: {
                        ARSelectionCard(
                            title: title,
                            isSelected: selectedCutoutID == asset.id
                        ) {
                            Image(uiImage: asset.image)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        }
                    }
                    .buttonStyle(ARPressButtonStyle())
                    .accessibilityLabel(title)
                    .accessibilityAddTraits(selectedCutoutID == asset.id ? .isSelected : [])
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var modelShelf: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(PlaceableUSDZModel.all) { model in
                Button {
                    selectedModelID = model.id
                    onSelectionFeedback()
                } label: {
                    ARSelectionCard(title: model.title, isSelected: selectedModelID == model.id) {
                        ARUSDZThumbnail(model: model)
                    }
                }
                .buttonStyle(ARPressButtonStyle())
                .accessibilityLabel(model.title)
                .accessibilityAddTraits(selectedModelID == model.id ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
#Preview("AR Transient Feedback") {
    ScrollView {
        VStack(spacing: 18) {
            NewARStatusPill(status: .searching)
            NewARStatusPill(status: .ready)
            NewARStatusPill(status: .loading("Preparing your model"))
            NewARStatusPill(status: .placed)
            NewARStatusPill(status: .limited("Move to a brighter area"))
            NewARStatusPill(status: .failed("Try restarting the AR session"))

            ARDeleteUndoToast {}

            ARTransientHint(message: "Tap empty space to show controls")
            ARTransientHint(message: "Hover Apple Pencil over an object to rotate it")
        }
        .padding(24)
    }
    .background(Color.Palette.n60)
}
#endif
