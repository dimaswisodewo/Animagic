//
//  ARPlacementStatus.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

enum ARPlacementStatus: Equatable {
    case searching
    case ready
    case loading(String)
    case limited(String)
    case placed
    case failed(String)
}
