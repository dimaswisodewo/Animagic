//
//  AniMagicDesignSystemModule.swift
//  AniMagicDesignSystem
//
//  Created by dimaswisodewo on 25/07/26.
//

import CoreText
import Foundation
import SwiftUI

/// Namespace for reusable AniMagic visual primitives and design tokens.
public enum AniMagicDesignSystemModule {
    public static func registerFonts() {
        let bundle = Bundle(for: DesignSystemBundleToken.self)
        for name in ["Belanosima-Bold", "Belanosima-Regular", "Belanosima-SemiBold"] {
            guard let url = bundle.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

private final class DesignSystemBundleToken: NSObject {}
