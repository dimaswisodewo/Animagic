//
//  ARPlacementControls.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

/// Sleek floating HUD for contextual placement instructions
struct ARInstructionBanner: View {
    let contentType: PlacementContentType
    let spawnMode: SpawnMode
    let status: ARPlacementStatus
    let sessionStatus: ARSessionStatus?

    init(
        contentType: PlacementContentType,
        spawnMode: SpawnMode,
        status: ARPlacementStatus,
        sessionStatus: ARSessionStatus? = nil
    ) {
        self.contentType = contentType
        self.spawnMode = spawnMode
        self.status = status
        self.sessionStatus = sessionStatus
    }

    private var title: String {
        if let sessionStatus {
            return sessionStatus.title
        }
        switch status {
        case .searching: return "Scanning Surface"
        case .ready: return "Surface Found"
        case .loading: return "Loading Model"
        case .placed: return "Placed"
        case .limited, .failed: return "Scanning Surface"
        }
    }

    private var detail: String {
        if let sessionStatus {
            if sessionStatus == .ready {
                return placementInstruction
            }
            return sessionStatus.message
        }
        switch status {
        case .loading(let message), .limited(let message), .failed(let message): return message
        default: return placementInstruction
        }
    }

    private var placementInstruction: String {
        contentType == .model
            ? "Tap floor to place"
            : spawnMode == .plane ? "Tap floor to spawn" : "Tap anywhere to spawn"
    }

    private var statusIcon: String {
        if let sessionStatus {
            return sessionStatus.systemImageName
        }
        switch status {
        case .ready: return "checkmark.circle.fill"
        case .loading: return "hourglass"
        case .placed: return "checkmark.circle"
        default: return "viewfinder"
        }
    }

    private var statusTint: Color {
        if let sessionStatus {
            return sessionStatus.tint
        }
        return status == .ready ? .green : .accentColor
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(statusTint)

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

private extension ARSessionStatus {
    var tint: Color {
        switch self {
        case .ready:
            .green
        case .noSurface:
            .orange
        case .unsupported, .cameraDenied, .failed:
            .red
        case .searching, .retrying:
            .accentColor
        }
    }
}

struct ARSessionStatusOverlay: View {
    let status: ARSessionStatus
    let onRetry: () -> Void
    let onOpenSettings: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: status.systemImageName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(status.tint)

                VStack(spacing: 6) {
                    Text(status.title)
                        .font(.title3.weight(.semibold))
                    Text(status.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if status == .retrying {
                    ProgressView()
                        .controlSize(.small)
                } else if status.offersSettings {
                    Button("Open Settings", action: onOpenSettings)
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Allow camera access before returning to AR.")

                    if status.allowsRetry {
                        Button("Retry", action: onRetry)
                            .buttonStyle(.bordered)
                    }
                } else if status.allowsRetry {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }

                Button("Back to Canvas", action: onBack)
                    .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 16)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
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
