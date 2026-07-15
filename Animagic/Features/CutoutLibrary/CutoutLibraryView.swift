//
//  ContentView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import PhotosUI
import SwiftUI

struct CutoutLibraryView: View {
    @Environment(NavigationRouter.self) private var router
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    @StateObject private var viewModel = CutoutLibraryViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showClearConfirmation = false
    @State private var recentlyCleared: [CutoutAsset] = []

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                imagePicker
                processingState
                librarySection
            }
            .padding()
        }
        .navigationTitle("Cutout Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !artworkStore.cutoutLibrary.isEmpty {
                Button("Clear") {
                    showClearConfirmation = true
                }
            }
        }
        .onChange(of: selectedPhotos) { _, newValue in
            Task {
                let newAssets = await viewModel.processImages(from: newValue)
                artworkStore.addCutouts(newAssets)
                selectedPhotos.removeAll()
            }
        }
        .confirmationDialog(
            "Clear all cutouts?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Cutouts", role: .destructive) {
                artworkStore.clearCutouts { recentlyCleared = $0 }
            }
        } message: {
            Text("This removes every cutout from your library. You can undo immediately.")
        }
        .safeAreaInset(edge: .bottom) {
            if !recentlyCleared.isEmpty {
                HStack {
                    Text("Library cleared")
                    Spacer()
                    Button("Undo") {
                        artworkStore.restoreCutouts(recentlyCleared)
                        recentlyCleared.removeAll()
                    }
                }
                .padding()
                .background(.thinMaterial, in: Capsule())
                .padding()
            }
        }
    }

    private var header: some View {
        Text("Select multiple images, extract their foreground objects, then spawn any saved cutout in AR.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var imagePicker: some View {
        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 12, matching: .images) {
            Label("Add Images", systemImage: "photo.stack")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isProcessing)
    }

    @ViewBuilder
    private var processingState: some View {
        if viewModel.isProcessing {
            ProgressView(
                "Creating cutouts \(viewModel.processedCount) of \(viewModel.totalSelectionCount)..."
            )
        }

        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var librarySection: some View {
        if artworkStore.cutoutLibrary.isEmpty {
            ContentUnavailableView(
                "No Cutouts Yet",
                systemImage: "photo.on.rectangle",
                description: Text("Add images to build a library of AR objects.")
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    router.push(.arView(initialCutoutID: artworkStore.cutoutLibrary.first?.id))
                } label: {
                    Label("Open AR Library", systemImage: "arkit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text("Library")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(artworkStore.cutoutLibrary) { cutoutAsset in
                        CutoutLibraryCell(
                            cutoutAsset: cutoutAsset,
                            allCutouts: artworkStore.cutoutLibrary,
                            onRemove: {
                                artworkStore.removeCutout(cutoutAsset)
                            },
                            onClassificationOverride: { label in
                                artworkStore.updateCutoutOverride(id: cutoutAsset.id, label: label)
                            }
                        )
                    }
                }
            }
        }
    }
}
