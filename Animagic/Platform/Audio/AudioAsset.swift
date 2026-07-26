//
//  AudioAssets.swift
//  AniMagic
//
//  Created by fajari bagas on 21/07/26.
//

enum AudioAsset: String {
    case tap
    case bgmHome = "bgm_home"
    
    var fileName: String {
        switch self {
        case .tap:
            return "tap"
        case .bgmHome:
            return "bgm_home"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .tap:
            return "mp3"
        case .bgmHome:
            return "mp3"
        }
    }
}
