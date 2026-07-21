//
//  AudioSessionManager.swift
//  AniMagic
//
//  Created by fajari bagas on 21/07/26.
//

import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    func configurateForPlayback() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }
    
    func deactivate(){
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Deactivating audio session failed: \(error.localizedDescription)")
        }
    }
}
