//
//  PlayNavigationActions.swift
//  AniMagicPlay
//
//  Created by dimaswisodewo on 25/07/26.
//

import SwiftUI

public struct PlayNavigationActions {
    public var exitToRoot: () -> Void
    public var openHelp: () -> Void
    public var requestCreation: () -> Void

    public init(
        exitToRoot: @escaping () -> Void = {},
        openHelp: @escaping () -> Void = {},
        requestCreation: @escaping () -> Void = {}
    ) {
        self.exitToRoot = exitToRoot
        self.openHelp = openHelp
        self.requestCreation = requestCreation
    }
}

private struct PlayNavigationActionsKey: EnvironmentKey {
    static let defaultValue = PlayNavigationActions()
}

public extension EnvironmentValues {
    var playNavigationActions: PlayNavigationActions {
        get { self[PlayNavigationActionsKey.self] }
        set { self[PlayNavigationActionsKey.self] = newValue }
    }
}
