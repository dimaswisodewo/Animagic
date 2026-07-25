//
//  CreationRepository.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation
import SwiftData

@MainActor
public protocol CreationRepository: AnyObject {
    func loadAll() throws -> [Creation]
    func save(_ creation: Creation) throws
    func delete(id: CreationID) throws
}

@MainActor
public final class SwiftDataCreationRepository: CreationRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
        context.autosaveEnabled = false
    }

    public func loadAll() throws -> [Creation] {
        let descriptor = FetchDescriptor<CreationRecord>(
            sortBy: [SortDescriptor(\CreationRecord.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.asValue() }
    }

    public func save(_ creation: Creation) throws {
        do {
            if let record = try record(id: creation.id) {
                record.update(from: creation)
            } else {
                context.insert(CreationRecord(creation))
            }
            try saveIfNeeded()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func delete(id: CreationID) throws {
        do {
            if let record = try record(id: id) {
                context.delete(record)
            }
            try saveIfNeeded()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func record(id: CreationID) throws -> CreationRecord? {
        let rawID = id.rawValue
        var descriptor = FetchDescriptor<CreationRecord>(
            predicate: #Predicate { $0.id == rawID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
