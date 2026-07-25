//
//  CreationRuntime.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation
import SwiftData

public struct CreationStartupIssue: LocalizedError, Sendable {
    public let errorDescription: String?

    public init(errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

@MainActor
public final class CreationRuntime {
    public let libraryStore: CreationLibraryStore
    public let startupIssue: CreationStartupIssue?

    private let modelContainer: ModelContainer

    private init(
        modelContainer: ModelContainer,
        libraryStore: CreationLibraryStore,
        startupIssue: CreationStartupIssue?
    ) {
        self.modelContainer = modelContainer
        self.libraryStore = libraryStore
        self.startupIssue = startupIssue
    }

    public static func openDefault() -> CreationRuntime {
        do {
            let container = try ModelContainer(
                for: Schema(ArtworkSchemaV2.models),
                migrationPlan: ArtworkMigrationPlan.self
            )
            return CreationRuntime(
                modelContainer: container,
                libraryStore: CreationLibraryStore(
                    repository: CreationLibraryRepositoryAdapter(context: container.mainContext)
                ),
                startupIssue: nil
            )
        } catch {
            do {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(
                    for: Schema(ArtworkSchemaV2.models),
                    configurations: configuration
                )
                let issue = CreationStartupIssue(errorDescription: """
                    Your saved creations could not be opened. AniMagic is running in a \
                    temporary library for this session. Your existing data has not been deleted.
                    """)
                return CreationRuntime(
                    modelContainer: container,
                    libraryStore: CreationLibraryStore(
                        repository: CreationLibraryRepositoryAdapter(context: container.mainContext)
                    ),
                    startupIssue: issue
                )
            } catch {
                fatalError("Unable to create a recovery Creation store: \(error.localizedDescription)")
            }
        }
    }
}
