//
//  HapticFeedback.swift
//  AniMagic
//
//  Created by dimaswisodewo on 22/07/26.
//

import CoreHaptics
import Foundation
import Observation
import UIKit

enum AnimagicHapticEvent: Equatable {
    case canvasStarted
    case firstStroke
    case drawingCleared
    case transformationCompleted
    case selection
    case dragStarted
    case placementCompleted
    case boundaryReached
    case detent
    case pencilTargetAcquired
    case pencilRotationCompleted
    case cameraShutter
    case recordingStarted
    case recordingStopped
    case success
    case warning
    case error
}

@MainActor
protocol HapticFeedbackProviding: AnyObject {
    var isEnabled: Bool { get set }

    func prepare()
    func play(_ event: AnimagicHapticEvent)
    func shutdown()
}

@Observable
@MainActor
final class HapticFeedbackManager: HapticFeedbackProviding {
    private enum PreferenceKey {
        static let isEnabled = "animagic.haptics.isEnabled"
    }

    private let defaults: UserDefaults
    private let supportsCustomHaptics: Bool
    private var engine: CHHapticEngine?
    private var isEngineRunning = false

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: PreferenceKey.isEnabled)
            if isEnabled {
                prepare()
            } else {
                shutdown()
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        supportsCustomHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if defaults.object(forKey: PreferenceKey.isEnabled) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: PreferenceKey.isEnabled)
        }
    }

    func prepare() {
        guard isEnabled, supportsCustomHaptics else { return }

        do {
            if engine == nil {
                try configureEngine()
            }
            try startEngineIfNeeded()
        } catch {
            isEngineRunning = false
        }
    }

    func play(_ event: AnimagicHapticEvent) {
        guard isEnabled else { return }

        switch event {
        case .canvasStarted:
            playCustom(Self.canvasLaunchPattern, fallback: .soft)
        case .transformationCompleted:
            playCustom(Self.transformationPattern, fallbackNotification: .success)
        case .placementCompleted:
            playCustom(Self.placementPattern, fallbackNotification: .success)
        case .cameraShutter:
            playCustom(Self.cameraShutterPattern, fallback: .heavy)
        case .firstStroke:
            impact(style: .soft, intensity: 0.35)
        case .drawingCleared:
            impact(style: .soft, intensity: 0.55)
        case .selection, .pencilTargetAcquired:
            UISelectionFeedbackGenerator().selectionChanged()
        case .dragStarted:
            impact(style: .light, intensity: 0.7)
        case .boundaryReached:
            impact(style: .rigid, intensity: 0.65)
        case .detent:
            impact(style: .light, intensity: 0.45)
        case .pencilRotationCompleted:
            impact(style: .soft, intensity: 0.65)
        case .recordingStarted:
            impact(style: .medium, intensity: 0.7)
        case .recordingStopped:
            impact(style: .soft, intensity: 0.6)
        case .success:
            notification(.success)
        case .warning:
            notification(.warning)
        case .error:
            notification(.error)
        }
    }

    func shutdown() {
        guard let engine else { return }
        isEngineRunning = false
        engine.stop(completionHandler: nil)
    }

    private func configureEngine() throws {
        let newEngine = try CHHapticEngine()
        newEngine.isAutoShutdownEnabled = true
        newEngine.playsHapticsOnly = true
        newEngine.stoppedHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isEngineRunning = false
            }
        }
        newEngine.resetHandler = { [weak self] in
            Task { @MainActor in
                guard let self, self.isEnabled else { return }
                self.isEngineRunning = false
                try? self.startEngineIfNeeded()
            }
        }
        engine = newEngine
    }

    private func startEngineIfNeeded() throws {
        guard !isEngineRunning, let engine else { return }
        try engine.start()
        isEngineRunning = true
    }

    private func playCustom(
        _ events: [CHHapticEvent],
        fallback: UIImpactFeedbackGenerator.FeedbackStyle
    ) {
        guard playPattern(events) else {
            impact(style: fallback)
            return
        }
    }

    private func playCustom(
        _ events: [CHHapticEvent],
        fallbackNotification: UINotificationFeedbackGenerator.FeedbackType
    ) {
        guard playPattern(events) else {
            notification(fallbackNotification)
            return
        }
    }

    private func playPattern(_ events: [CHHapticEvent]) -> Bool {
        guard supportsCustomHaptics else { return false }

        do {
            if engine == nil {
                try configureEngine()
            }
            try startEngineIfNeeded()
            guard let engine else { return false }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            isEngineRunning = false
            return false
        }
    }

    private func impact(
        style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat = 1
    ) {
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }

    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private static var canvasLaunchPattern: [CHHapticEvent] {
        [transient(time: 0, intensity: 0.28, sharpness: 0.12)]
    }

    private static var transformationPattern: [CHHapticEvent] {
        [
            continuous(time: 0, duration: 0.32, intensity: 0.18, sharpness: 0.08),
            transient(time: 0.06, intensity: 0.28, sharpness: 0.12),
            transient(time: 0.17, intensity: 0.48, sharpness: 0.22),
            transient(time: 0.31, intensity: 0.78, sharpness: 0.38)
        ]
    }

    private static var placementPattern: [CHHapticEvent] {
        [
            transient(time: 0, intensity: 0.66, sharpness: 0.2),
            continuous(time: 0.02, duration: 0.16, intensity: 0.2, sharpness: 0.06)
        ]
    }

    private static var cameraShutterPattern: [CHHapticEvent] {
        [
            transient(time: 0, intensity: 0.82, sharpness: 0.58),
            transient(time: 0.07, intensity: 0.3, sharpness: 0.18)
        ]
    }

    private static func transient(
        time: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: parameters(intensity: intensity, sharpness: sharpness),
            relativeTime: time
        )
    }

    private static func continuous(
        time: TimeInterval,
        duration: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: parameters(intensity: intensity, sharpness: sharpness),
            relativeTime: time,
            duration: duration
        )
    }

    private static func parameters(
        intensity: Float,
        sharpness: Float
    ) -> [CHHapticEventParameter] {
        [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
    }
}
