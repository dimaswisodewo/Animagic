//
//  CreationResources.swift
//  AniMagicCreation
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation

private final class CreationBundleToken: NSObject {}

extension Bundle {
    static let aniMagicCreation = Bundle(for: CreationBundleToken.self)
}
