//
//  PersistenceAlert.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import Foundation

struct PersistenceAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let retry: @MainActor () -> Void
}
