//
//  ContentView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import PhotosUI
import SwiftUI

struct CutoutLibraryView: View {
    @EnvironmentObject var appState: AppState
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
            if !appState.cutoutLibrary.isEmpty {
                Button("Clear") {
                    showClearConfirmation = true
                }
            }
        }
        .onChange(of: selectedPhotos) { _, newValue in
            Task {
                let newAssets = await viewModel.processImages(from: newValue)
                newAssets.forEach(appState.addCutout)
                selectedPhotos.removeAll()
            }
        }
        .confirmationDialog(
            "Clear all cutouts?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Cutouts", role: .destructive) {
                recentlyCleared = appState.clearCutouts()
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
                        appState.restoreCutouts(recentlyCleared)
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
        if appState.cutoutLibrary.isEmpty {
            ContentUnavailableView(
                "No Cutouts Yet",
                systemImage: "photo.on.rectangle",
                description: Text("Add images to build a library of AR objects.")
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink {
                    ARObjectPlacementView(cutoutAssets: appState.cutoutLibrary)
                } label: {
                    Label("Open AR Library", systemImage: "arkit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text("Library")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(appState.cutoutLibrary) { cutoutAsset in
                        CutoutLibraryCell(
                            cutoutAsset: cutoutAsset,
                            allCutouts: appState.cutoutLibrary,
                            onRemove: {
                                appState.removeCutout(cutoutAsset)
                            },
                            onClassificationOverride: { label in
                                appState.updateCutoutOverride(id: cutoutAsset.id, label: label)
                            }
                        )
                    }
                }
            }
        }
    }
}
