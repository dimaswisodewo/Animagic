//
//  AppRoute+Modifier.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 17/07/26.
//

import SwiftUI
import AniMagicCreation
import AniMagicPlay

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
                .modifier(ModuleNavigationActionsModifier())
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
                .modifier(ModuleNavigationActionsModifier())
                .modifier(FullScreenCoverStackModifier(index: index + 1))
        }
    }
}

struct AppRouterView {
    @ViewBuilder static func handleNavigation(_ route: AppRoute) -> some View {
        Group {
            switch route {
            case .canvas: CanvasPageView(completionBehavior: .openNewAR)
            case .play(let intent): PlayRouteView(intent: intent)
            case .backpack: BackpackPageView()
            case .handdrawnDetail(let id): HanddrawnDetailView(drawingID: id)
            case .cutoutLibrary: CutoutLibraryView()
            case .help: HelpPageView()
#if DEBUG
            case .motionLab: MotionLabView()
#endif
            }
        }
        .modifier(ModuleNavigationActionsModifier())
    }

    @ViewBuilder static func handlePresentation(_ route: AppRoute) -> some View {
        EmptyView()
    }

    @ViewBuilder static func handleFullScreenCover(_ route: AppRoute) -> some View {
        switch route {
        case .canvas:
            CanvasPageView(completionBehavior: .returnToPresentingAR)
        default:
            EmptyView()
        }
    }
}

private struct ModuleNavigationActionsModifier: ViewModifier {
    @Environment(NavigationRouter.self) private var router

    func body(content: Content) -> some View {
        content
            .environment(\.creationNavigationActions, CreationNavigationActions(
                goBack: router.pop,
                openCanvas: { router.push(.canvas) },
                openDetail: { router.push(.handdrawnDetail($0)) },
                openPlay: {
                    router.push(.play(PlayIntent(
                        environment: .augmentedReality,
                        initialCreationID: $0
                    )))
                },
                completePresentedCanvas: { _ in router.dismissFullScreenCover() }
            ))
            .environment(\.playNavigationActions, PlayNavigationActions(
                exitToRoot: router.popToRoot,
                openHelp: { router.push(.help) },
                requestCreation: { router.presentFullScreenCover(.canvas) }
            ))
    }
}

private struct PlayRouteView: View {
    @EnvironmentObject private var artworkStore: CreationLibraryStore
    let intent: PlayIntent

    @ViewBuilder
    var body: some View {
        switch intent.environment {
        case .augmentedReality:
            NewARPlacementView(initialCutoutID: intent.initialCreationID)
        case .virtualRoom:
            VirtualRoomView()
        }
    }
}

extension View {
    func withAppRouter() -> some View { modifier(RouterViewModifier()) }
}
