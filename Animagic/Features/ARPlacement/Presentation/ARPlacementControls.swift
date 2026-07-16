//
//  ARPlacementControls.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

struct ARInstructionBanner: View {
    let status: ARSessionStatus
    let spawnMode: SpawnMode

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.systemImageName)
                .font(.title3)
                .foregroundStyle(status.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                .font(.headline)
                Text(status == .ready ? spawnMode.instruction : status.message)
                    .font(.subheadline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                } else {
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

struct SpawnModePicker: View {
    @Binding var selection: SpawnMode

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SpawnMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Label(mode.title, systemImage: mode.systemImageName)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(selection == mode ? Color.accentColor : Color.primary)
                        .background(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selection == mode ? Color.accentColor : Color.clear, lineWidth: 3)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CutoutPicker: View {
    let assets: [CutoutAsset]
    @Binding var selection: CutoutAsset.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(assets) { asset in
                    Button {
                        selection = asset.id
                    } label: {
                        Image(uiImage: asset.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .padding(6)
                            .background(Color(.secondarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selection == asset.id ? Color.accentColor : Color.clear, lineWidth: 3)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AnimalArchetypePicker: View {
    @Binding var selection: AnimalArchetype

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AnimalArchetype.allCases) { archetype in
                    Button {
                        selection = archetype
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: archetype.systemImageName)
                                .font(.headline)
                            Text(archetype.title)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(selection == archetype ? Color.accentColor : Color.primary)
                        .frame(width: 110, height: 64)
                        .background(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selection == archetype ? Color.accentColor : Color.clear, lineWidth: 3)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SelectedObjectToolbar: View {
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Label("Object selected", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
