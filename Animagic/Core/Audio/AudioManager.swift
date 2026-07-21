//
//  AudioManager.swift
//  AniMagic
//
//  Created by fajari bagas on 21/07/26.
//

import AVFAudio

final class AudioManager {
    static let shared = AudioManager()
    static let tapGainDecibels: Float = 6.0
    
    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [String: AVAudioPlayer] = [:]
    private let tapEngine = AVAudioEngine()
    private let tapPlayer = AVAudioPlayerNode()
    private let tapEqualizer = AVAudioUnitEQ(numberOfBands: 1)
    private var tapEngineConfigured = false
    private var tapBuffer: AVAudioPCMBuffer?
    
    func setup() {
        AudioSessionManager.shared.configurateForPlayback()
        prepareTapSound()
    }
    
    func playMusic(_ asset: AudioAsset, loop: Bool = true, volume:Float = 0.6) {
        guard let url = Bundle.main.url(forResource: asset.fileName, withExtension: asset.fileExtension) else { return }
        
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

    func playTap() {
        if tapBuffer == nil {
            prepareTapSound()
        }

        guard let tapBuffer else { return }

        do {
            if !tapEngine.isRunning {
                try tapEngine.start()
            }
            tapPlayer.stop()
            tapPlayer.scheduleBuffer(tapBuffer)
            tapPlayer.play()
        } catch {
            print("Tap SFX playback error: \(error.localizedDescription)")
        }
    }

    private func prepareTapSound() {
        guard tapBuffer == nil else { return }
        guard let url = Bundle.main.url(
            forResource: AudioAsset.tap.fileName,
            withExtension: AudioAsset.tap.fileExtension
        ) else { return }

        do {
            AudioSessionManager.shared.configurateForPlayback()
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return }

            try file.read(into: buffer)
            try configureTapEngine(using: file.processingFormat)
            tapBuffer = buffer
        } catch {
            print("Tap SFX preparation error: \(error.localizedDescription)")
        }
    }

    private func configureTapEngine(using format: AVAudioFormat) throws {
        if !tapEngineConfigured {
            tapEngine.attach(tapPlayer)
            tapEngine.attach(tapEqualizer)
            tapEqualizer.globalGain = Self.tapGainDecibels
            tapEngine.connect(tapPlayer, to: tapEqualizer, format: format)
            tapEngine.connect(tapEqualizer, to: tapEngine.mainMixerNode, format: nil)
            tapEngine.mainMixerNode.outputVolume = 1.0
            tapEngineConfigured = true
        }

        if !tapEngine.isRunning {
            try tapEngine.start()
        }
    }
}
