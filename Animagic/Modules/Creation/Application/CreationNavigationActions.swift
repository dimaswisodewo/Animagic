//
//  CreationNavigationActions.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation
import SwiftUI

public struct CreationNavigationActions {
    public var goBack: () -> Void
    public var openCanvas: () -> Void
    public var openDetail: (UUID) -> Void
    public var openPlay: (UUID?) -> Void
    public var completePresentedCanvas: (UUID) -> Void

    public init(
        goBack: @escaping () -> Void = {},
        openCanvas: @escaping () -> Void = {},
        openDetail: @escaping (UUID) -> Void = { _ in },
        openPlay: @escaping (UUID?) -> Void = { _ in },
        completePresentedCanvas: @escaping (UUID) -> Void = { _ in }
    ) {
        self.goBack = goBack
        self.openCanvas = openCanvas
        self.openDetail = openDetail
        self.openPlay = openPlay
        self.completePresentedCanvas = completePresentedCanvas
    }
}

private struct CreationNavigationActionsKey: EnvironmentKey {
    static let defaultValue = CreationNavigationActions()
}

public extension EnvironmentValues {
    var creationNavigationActions: CreationNavigationActions {
        get { self[CreationNavigationActionsKey.self] }
        set { self[CreationNavigationActionsKey.self] = newValue }
    }
}
