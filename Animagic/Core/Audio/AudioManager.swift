//
//  AudioManager.swift
//  AniMagic
//
//  Created by fajari bagas on 21/07/26.
//

import AVFAudio

final class AudioManager {
    static let shared = AudioManager()
    
    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [String: AVAudioPlayer] = [:]
    
    func setup() {
        AudioSessionManager.shared.configurateForPlayback()
    }
    
    func playMusic(_ asset: AudioAsset, loop: Bool = true, volume:Float = 0.6) {
        guard let url = Bundle.main.url(forResource: asset.fileName, withExtension: "asset.fileExtension") else { return }
        
        do{
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.volume = volume
            musicPlayer?.prepareToPlay()
            musicPlayer?.play()
        } catch {
            print("Music error: \(error.localizedDescription)")
        }
    }
    
    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }
    
    func pauseMusic() {
        musicPlayer?.pause()
    }
    
    func resumeMusic() {
        musicPlayer?.play()
    }
    
    func playSFX(_ asset: AudioAsset, volume:Float = 1.0) {
        let key = asset.fileName
        
        guard let url = Bundle.main.url(forResource: asset.fileName, withExtension: asset.fileExtension) else { return }
        
        do{
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            sfxPlayers[key] = player
        } catch {
            print("SFX error: \(error.localizedDescription)")
        }
    }
}
