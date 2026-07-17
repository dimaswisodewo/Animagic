//
//  VirtualRoomModels.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 16/07/26.
//

import RealityKit

enum VirtualRoomInteractionMode: String, CaseIterable, Identifiable {
    case explore
    case edit
    case interact

    var id: String { rawValue }
    var title: String {
        switch self {
        case .explore: return "Explore"
        case .edit: return "Creation"
        case .interact: return "Interaction"
        }
    }
    var systemImageName: String {
        switch self {
        case .explore: return "figure.walk"
        case .edit: return "wand.and.stars"
        case .interact: return "hand.draw"
        }
    }
}

enum VirtualRoomSkybox: String, CaseIterable, Identifiable {
    case citrusOrchard = "CitrusOrchard"
    case land = "Land"
    case underwater = "Underwater"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .citrusOrchard: "Citrus Orchard"
        case .land: "Land"
        case .underwater: "Underwater"
        }
    }
}

enum SkyboxLoadState: Equatable {
    case loading
    case loaded(VirtualRoomSkybox)
    case failed(String)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
