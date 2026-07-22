//
//  BackgroundMusicController.swift
//  AniMagic
//
//  Created by dimaswisodewo on 22/07/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class BackgroundMusicController {
    private enum PreferenceKey {
        static let isEnabled = "animagic.backgroundMusic.isEnabled"
    }

    private let defaults: UserDefaults
    private let audioManager: AudioManager
    private var hasConfiguredAudio = false
    private var hasStartedMusic = false
    private var isSceneActive = false

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: PreferenceKey.isEnabled)
            updatePlayback()
        }
    }

    init(
        defaults: UserDefaults = .standard,
        audioManager: AudioManager? = nil
    ) {
        self.defaults = defaults
        self.audioManager = audioManager ?? .shared
        if defaults.object(forKey: PreferenceKey.isEnabled) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: PreferenceKey.isEnabled)
        }
    }

    func activate() {
        isSceneActive = true
        configureAudioIfNeeded()
        updatePlayback()
    }

    func deactivate() {
        isSceneActive = false
        audioManager.pauseMusic()
    }

    func toggle() {
        isEnabled.toggle()
    }

    private func configureAudioIfNeeded() {
        guard !hasConfiguredAudio else { return }
        audioManager.setup()
        hasConfiguredAudio = true
    }

    private func updatePlayback() {
        guard isSceneActive else { return }
        configureAudioIfNeeded()

        guard isEnabled else {
            audioManager.pauseMusic()
            return
        }

        if hasStartedMusic {
            audioManager.resumeMusic()
        } else {
            audioManager.playMusic(.bgmHome)
            hasStartedMusic = true
        }
    }
}
