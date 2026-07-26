//
//  AppRoute.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

enum AppRoute: Hashable, Identifiable {
    case drawingCanvas
    case arPlacement(initialCutoutID: UUID?)
    case backpack
    case drawingDetail(UUID)
    case cutoutLibrary
    case virtualRoom
    case help
#if DEBUG
    case motionLab
#endif

    var id: Self { self }
}
