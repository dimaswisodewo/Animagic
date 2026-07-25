//
//  SupportResources.swift
//  AniMagicSupport
//
//  Created by dimaswisodewo on 25/07/26.
//

import Foundation

private final class SupportBundleToken: NSObject {}

extension Bundle {
    static let aniMagicSupport = Bundle(for: SupportBundleToken.self)
}
