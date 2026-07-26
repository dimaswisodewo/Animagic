//
//  AppRoute+Modifier.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 17/07/26.
//

import SwiftUI

struct RouterViewModifier: ViewModifier {
    @Environment(NavigationRouter.self) private var router

    func body(content: Content) -> some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            content
                .navigationDestination(for: AppRoute.self) { AppRouterView.handleNavigation($0) }
                .modifier(SheetStackModifier(index: 0))
                .modifier(FullScreenCoverStackModifier(index: 0))
        }
    }
}

struct SheetStackModifier: ViewModifier {
    @Environment(NavigationRouter.self) private var router
    let index: Int

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { router.presentedSheets.indices.contains(index) ? router.presentedSheets[index] : nil },
            set: { if $0 == nil, router.presentedSheets.indices.contains(index) { router.presentedSheets.removeSubrange(index...) } }
        )) { route in
            AppRouterView.handlePresentation(route)
                .modifier(SheetStackModifier(index: index + 1))
        }
    }
}

struct FullScreenCoverStackModifier: ViewModifier {
    @Environment(NavigationRouter.self) private var router
    let index: Int

    func body(content: Content) -> some View {
        content.fullScreenCover(item: Binding(
            get: { router.presentedFullScreenCovers.indices.contains(index) ? router.presentedFullScreenCovers[index] : nil },
            set: {
                if $0 == nil, router.presentedFullScreenCovers.indices.contains(index) {
                    router.presentedFullScreenCovers.removeSubrange(index...)
                }
            }
        )) { route in
            AppRouterView.handleFullScreenCover(route)
                .modifier(FullScreenCoverStackModifier(index: index + 1))
        }
    }
}

extension View {
    func withAppRouter() -> some View { modifier(RouterViewModifier()) }
}
