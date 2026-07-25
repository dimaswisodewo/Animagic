//
//  PlayResources.swift
//  AniMagicPlay
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation

private final class PlayBundleToken: NSObject {}

extension Bundle {
    static let aniMagicPlay = Bundle(for: PlayBundleToken.self)
}
