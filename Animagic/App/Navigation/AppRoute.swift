//
//  AppRoute.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Observation
import SwiftUI

enum AppRoute: Hashable, Identifiable {
    case canvas
    case arView(initialCutoutID: UUID?)
    case backpack
    case handdrawnDetail(UUID)
    case cutoutLibrary
    case virtualRoom
    case help
#if DEBUG
    case motionLab
#endif

    var id: Self { self }
}

@MainActor
@Observable
final class NavigationRouter {
    var path: [AppRoute] = []
    var presentedSheets: [AppRoute] = []
    var presentedFullScreenCovers: [AppRoute] = []

    var presentedSheet: AppRoute? {
        get { presentedSheets.first }
        set {
            if let newValue, !presentedSheets.contains(newValue) {
                presentedSheets.append(newValue)
            } else if newValue == nil {
                presentedSheets.removeAll()
            }
        }
    }

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }

    func replace(_ route: AppRoute, with newRoute: AppRoute) {
        if let index = path.firstIndex(of: route) { path[index] = newRoute } else { push(newRoute) }
    }

    func presentSheet(_ route: AppRoute) { presentedSheets.append(route) }
    func presentFullScreenCover(_ route: AppRoute) { presentedFullScreenCovers.append(route) }
    func dismissSheet() { if !presentedSheets.isEmpty { presentedSheets.removeLast() } }
    func dismissFullScreenCover() { if !presentedFullScreenCovers.isEmpty { presentedFullScreenCovers.removeLast() } }
    func dismiss() {
        presentedSheets.removeAll()
        presentedFullScreenCovers.removeAll()
    }
}
