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

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImageName: String { self == .explore ? "figure.walk" : "wand.and.stars" }
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
