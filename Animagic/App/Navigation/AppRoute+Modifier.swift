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

struct AppRouterView {
    @ViewBuilder static func handleNavigation(_ route: AppRoute) -> some View {
        switch route {
        case .canvas: CanvasPageView()
        case .arView(let initialCutoutID): ARRouteView(initialCutoutID: initialCutoutID)
        case .backpack: BackpackPageView()
        case .handdrawnDetail(let id): HanddrawnDetailView(drawingID: id)
        case .cutoutLibrary: CutoutLibraryView()
        case .virtualRoom: VirtualRoomView()
        case .help: HelpPageView()
        }
    }

    @ViewBuilder static func handlePresentation(_ route: AppRoute) -> some View {
        EmptyView()
    }

    @ViewBuilder static func handleFullScreenCover(_ route: AppRoute) -> some View {
        EmptyView()
    }
}

private struct ARRouteView: View {
    @EnvironmentObject private var artworkStore: ArtworkLibraryStore
    let initialCutoutID: UUID?

    var body: some View {
        NewARPlacementView(initialCutoutID: initialCutoutID)
    }
}

extension View {
    func withAppRouter() -> some View { modifier(RouterViewModifier()) }
}
