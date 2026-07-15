//
//  ARPlacementControls.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

struct ARInstructionBanner: View {
    let contentType: PlacementContentType
    let spawnMode: SpawnMode
    let status: ARPlacementStatus

    private var title: String {
        switch status {
        case .searching: return "Scan for a horizontal surface"
        case .ready: return "Surface found — tap to place"
        case .loading: return "Loading 3D model"
        case .placed: return "Placed"
        case .limited, .failed: return "Keep scanning"
        }
    }

    private var detail: String {
        switch status {
        case .loading(let message), .limited(let message), .failed(let message): return message
        default:
            return contentType == .model
                ? "Choose a 3D model, then tap a horizontal surface to place it."
                : spawnMode.instruction
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Label(title, systemImage: status == .ready ? "checkmark.circle.fill" : "viewfinder")
                .font(.headline)
            Text(detail)
                .font(.subheadline)
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PlacementContentTypePicker: View {
    @Binding var selection: PlacementContentType

    var body: some View {
        Picker("Content type", selection: $selection) {
            ForEach(PlacementContentType.allCases) { type in
                Text(type.title).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct EmptyDoodleLibraryMessage: View {
    var body: some View {
        Text("Create a cutout in the library before placing a doodle.")
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct USDZModelPicker: View {
    @Binding var selection: PlaceableUSDZModel.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlaceableUSDZModel.all) { model in
                    Button {
                        selection = model.id
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: model.systemImageName)
                                .font(.title3)
                            Text(model.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(selection == model.id ? Color.accentColor : Color.primary)
                        .frame(width: 100, height: 64)
                        .background(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selection == model.id ? Color.accentColor : Color.clear, lineWidth: 3)
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
    let title: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Label("\(title) selected", systemImage: "checkmark.circle.fill")
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
