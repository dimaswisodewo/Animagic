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
        HStack(spacing: 0) {
            ForEach(PlacementContentType.allCases) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = type
                    }
                } label: {
                    Text(type.title)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == type ? Color.accentColor : Color.clear)
                        .foregroundStyle(selection == type ? .white : .primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(2)
        .background(Color(.systemGroupedBackground).opacity(0.8))
        .clipShape(Capsule())
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

    private var content: (title: String, detail: String, icon: String, color: Color) {
        switch status {
        case .searching:
            ("Finding a surface", "Move slowly over a floor or table", "viewfinder", .yellow)
        case .ready:
            ("Ready to place", "Aim the reticle, then tap Place", "checkmark.circle.fill", .green)
        case .loading(let message):
            ("Getting it ready", message, "hourglass", .yellow)
        case .placed:
            ("Magic placed!", "Drag, pinch, or twist to adjust it", "sparkles", .green)
        case .limited(let message):
            ("Tracking paused", message, "exclamationmark.triangle.fill", .orange)
        case .failed(let message):
            ("Something went wrong", message, "exclamationmark.circle.fill", .red)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: content.icon)
                .font(.headline)
                .foregroundStyle(content.color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(content.title)
                    .font(.caption.bold())
                Text(content.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
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
    @Binding var animalArchetype: AnimalArchetype
    let onDone: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                gestureHint(icon: "hand.draw.fill", title: "Drag to move")
                gestureHint(icon: "arrow.up.left.and.arrow.down.right", title: "Pinch to resize")
                gestureHint(icon: "rotate.3d", title: "Twist to turn")
            }
            .frame(maxWidth: .infinity)

            Divider().opacity(0.4)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                Text(selection.title)
                    .font(.callout.bold())
                    .lineLimit(1)

                if selection.animalArchetype != nil {
                    Menu {
                        Picker("Moves like", selection: $animalArchetype) {
                            ForEach(AnimalArchetype.allCases) { archetype in
                                Label(archetype.title, systemImage: archetype.systemImageName)
                                    .tag(archetype)
                            }
                        }
                    } label: {
                        Label("Moves like \(animalArchetype.title)", systemImage: animalArchetype.systemImageName)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                    .accessibilityLabel("Movement behavior, \(animalArchetype.title)")
                }

                Spacer(minLength: 8)

                Button("Done", action: onDone)
                    .font(.callout.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Color.yellow, in: Capsule())
                    .buttonStyle(ARPressButtonStyle())

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(ARPressButtonStyle())
                .accessibilityLabel("Delete \(selection.title)")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
    }

    private func gestureHint(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityLabel(title)
    }
}

struct ARDeleteUndoToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
            Text("Object deleted")
                .font(.callout.bold())
            Button("Undo", action: onUndo)
                .font(.callout.bold())
                .foregroundStyle(.yellow)
                .frame(minHeight: 44)
        }
        .foregroundStyle(.white)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .background(Color.black.opacity(0.82), in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }
}

private struct ARSelectionCard<Preview: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let preview: Preview

    var body: some View {
        VStack(spacing: 4) {
            preview
                .frame(width: 68, height: 56)
            Text(title)
                .font(.caption2.bold())
                .lineLimit(1)
                .frame(maxWidth: 82)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(width: 94)
        .frame(minHeight: 84)
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

private struct ARUSDZThumbnail: View {
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
