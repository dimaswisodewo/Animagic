//
//  CutoutLibraryCell.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

struct CutoutLibraryCell: View {
    let cutoutAsset: CutoutAsset
    let allCutouts: [CutoutAsset]
    let onRemove: () -> Void
    let onClassificationOverride: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(uiImage: cutoutAsset.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(CheckerboardBackground())
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("\(Int(cutoutAsset.originalSize.width)) x \(Int(cutoutAsset.originalSize.height)) px")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let label = cutoutAsset.resolvedDoodleLabel {
                Label(
                    cutoutAsset.doodleOverrideLabel == nil && cutoutAsset.doodleClassification != nil
                        ? "\(label.capitalized) \(cutoutAsset.doodleClassification!.confidence, format: .percent.precision(.fractionLength(0)))"
                        : "\(label.capitalized) (manual)",
                    systemImage: "wand.and.stars"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let error = cutoutAsset.doodleClassificationError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Menu {
                Button("Use AI Suggestion") { onClassificationOverride(nil) }
                ForEach(DoodleSpecies.all, id: \.self) { label in
                    Button(label.capitalized) { onClassificationOverride(label) }
                }
            } label: {
                Label("Change animal", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            HStack {
                NavigationLink {
                    ARObjectPlacementView(
                        cutoutAssets: allCutouts,
                        initialCutoutID: cutoutAsset.id
                    )
                } label: {
                    Image(systemName: "arkit")
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
