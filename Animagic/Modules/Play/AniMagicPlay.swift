//
//  AniMagicPlay.swift
//  AniMagicPlay
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation
import AniMagicCreation
import Observation

public enum PlayEnvironment: String, CaseIterable, Hashable, Identifiable, Sendable {
    case augmentedReality
    case virtualRoom

    public var id: Self { self }
}

public struct PlayIntent: Equatable, Hashable, Sendable {
    public let environment: PlayEnvironment
    public let initialCreationID: UUID?

    public init(environment: PlayEnvironment, initialCreationID: UUID? = nil) {
        self.environment = environment
        self.initialCreationID = initialCreationID
    }
}

@MainActor
@Observable
public final class PlaySessionModel {
    public private(set) var intent: PlayIntent
    public private(set) var isPaused = false

    public init(intent: PlayIntent) {
        self.intent = intent
    }

    public func selectCreation(_ creationID: UUID?) {
        intent = PlayIntent(environment: intent.environment, initialCreationID: creationID)
    }

    public func switchEnvironment(to environment: PlayEnvironment) {
        intent = PlayIntent(environment: environment, initialCreationID: intent.initialCreationID)
    }

    public func pause() { isPaused = true }
    public func resume() { isPaused = false }
}
