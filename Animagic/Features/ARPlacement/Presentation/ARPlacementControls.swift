//
//  ARPlacementControls.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

struct ARInstructionBanner: View {
    let spawnMode: SpawnMode

    var body: some View {
        VStack(spacing: 8) {
            Text("Move the device to find a plane")
                .font(.headline)
            Text(spawnMode.instruction)
                .font(.subheadline)
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(maxWidth: .infinity)
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
