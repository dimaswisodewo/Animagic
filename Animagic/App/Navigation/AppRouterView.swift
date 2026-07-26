//
//  AppRouterView.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import SwiftUI

struct AppRouterView {
    @ViewBuilder
    static func handleNavigation(_ route: AppRoute) -> some View {
        switch route {
        case .drawingCanvas: DrawingCanvasView(completionBehavior: .openARPlacement)
        case .arPlacement(let initialCutoutID): ARRouteView(initialCutoutID: initialCutoutID)
        case .backpack: BackpackView()
        case .drawingDetail(let id): DrawingDetailView(drawingID: id)
        case .cutoutLibrary: CutoutLibraryView()
        case .virtualRoom: VirtualRoomView()
        case .help: HelpView()
#if DEBUG
        case .motionLab: MotionLabView()
#endif
        }
    }

    @ViewBuilder
    static func handlePresentation(_ route: AppRoute) -> some View {
        EmptyView()
    }

    @ViewBuilder
    static func handleFullScreenCover(_ route: AppRoute) -> some View {
        switch route {
        case .drawingCanvas:
            DrawingCanvasView(completionBehavior: .returnToPresentingAR)
        default:
            EmptyView()
        }
    }
}

private struct ARRouteView: View {
    let initialCutoutID: UUID?

    var body: some View {
        ARPlacementView(initialCutoutID: initialCutoutID)
    }
}
