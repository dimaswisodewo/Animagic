//
//  LocomotionConfiguration.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import GameplayKit

enum SpawnMode: String, CaseIterable, Identifiable {
    case plane
    case cameraRoam

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plane: "Plane"
        case .cameraRoam: "Roam"
        }
    }

    var systemImageName: String {
        switch self {
        case .plane: "square.grid.3x3"
        case .cameraRoam: "camera.viewfinder"
        }
    }

    var instruction: String {
        switch self {
        case .plane:
            "Choose an object and movement, then tap a horizontal surface to spawn it."
        case .cameraRoam:
            "Choose an object and movement, then tap anywhere to spawn it roaming around that area."
        }
    }
}

enum AnimalLocomotion: String, CaseIterable, Identifiable {
    case swim, fly, flutter, walk, stomp, hop, slither, scuttle, crawl, waddle, generic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .swim: "Swims"
        case .fly: "Flies"
        case .flutter: "Flutters"
        case .walk: "Walks"
        case .stomp: "Stomps"
        case .hop: "Hops"
        case .slither: "Slithers"
        case .scuttle: "Scuttles"
        case .crawl: "Crawls"
        case .waddle: "Waddles"
        case .generic: "Wanders"
        }
    }

    var systemImageName: String {
        switch self {
        case .swim: "fish.fill"
        case .fly: "bird.fill"
        case .flutter: "camera.macro"
        case .walk: "cat.fill"
        case .stomp: "pawprint.fill"
        case .hop: "hare.fill"
        case .slither: "waveform.path"
        case .scuttle: "arrow.left.and.right"
        case .crawl: "ant.fill"
        case .waddle: "figure.walk"
        case .generic: "sparkles"
        }
    }

    var verticalStyle: VerticalMotionStyle {
        switch self {
        case .swim: .floating
        case .fly, .flutter: .flying
        default: .grounded
        }
    }
}

enum AnimalBodyStyle: Int, CaseIterable {
    case generic
    case finned
    case winged
    case flutterWinged
    case flexibleQuadruped
    case heavyQuadruped
    case hopper
    case serpentine
    case crawler
    case crustacean
    case flippered
    case softBodied

    var shaderIndex: Float { Float(rawValue) }
}

struct AnimalMotionProfile: Equatable {
    let locomotion: AnimalLocomotion
    let bodyStyle: AnimalBodyStyle

    static let generic = Self(locomotion: .generic, bodyStyle: .generic)
}

enum AnimalMotionProfileResolver {
    static let confidenceThreshold: Float = 0.5

    static func profile(for asset: CutoutAsset?) -> AnimalMotionProfile {
        guard let asset else { return .generic }
        if let overrideLabel = asset.doodleOverrideLabel {
            return profile(forLabel: overrideLabel, confidence: 1)
        }
        guard let classification = asset.doodleClassification else { return .generic }
        return profile(forLabel: classification.label, confidence: classification.confidence)
    }

    static func profile(forLabel label: String, confidence: Float) -> AnimalMotionProfile {
        guard confidence >= confidenceThreshold,
              let species = DoodleSpecies(rawValue: label.lowercased()),
              species != .other else {
            return .generic
        }
        return AnimalMotionProfile(
            locomotion: locomotion(for: species),
            bodyStyle: bodyStyle(for: species)
        )
    }

    private static func locomotion(for species: DoodleSpecies) -> AnimalLocomotion {
        switch species {
        case .duck, .swan, .dolphin, .fish, .shark, .whale, .seaTurtle, .octopus:
            .swim
        case .bat, .bird, .owl, .parrot:
            .fly
        case .bee, .butterfly, .mosquito:
            .flutter
        case .flamingo, .cat, .dog, .giraffe, .hedgehog, .horse, .lion, .monkey,
             .mouse, .pig, .raccoon, .sheep, .squirrel, .tiger, .zebra:
            .walk
        case .bear, .camel, .cow, .elephant, .panda, .rhinoceros:
            .stomp
        case .kangaroo, .rabbit, .frog:
            .hop
        case .snake, .snail:
            .slither
        case .crab, .lobster:
            .scuttle
        case .ant, .scorpion, .spider, .crocodile:
            .crawl
        case .penguin:
            .waddle
        case .other:
            .generic
        }
    }

    private static func bodyStyle(for species: DoodleSpecies) -> AnimalBodyStyle {
        switch species {
        case .dolphin, .fish, .shark, .whale:
            .finned
        case .bat, .bird, .duck, .flamingo, .owl, .parrot, .penguin, .swan:
            .winged
        case .bee, .butterfly, .mosquito:
            .flutterWinged
        case .cat, .dog, .giraffe, .hedgehog, .horse, .lion, .monkey, .mouse,
             .pig, .raccoon, .sheep, .squirrel, .tiger, .zebra:
            .flexibleQuadruped
        case .bear, .camel, .cow, .elephant, .panda, .rhinoceros:
            .heavyQuadruped
        case .kangaroo, .rabbit, .frog:
            .hopper
        case .snake, .snail:
            .serpentine
        case .ant, .scorpion, .spider, .crocodile:
            .crawler
        case .crab, .lobster:
            .crustacean
        case .seaTurtle:
            .flippered
        case .octopus:
            .softBodied
        case .other:
            .generic
        }
    }
}

enum VerticalMotionStyle {
    case grounded
    case floating
    case flying
}

enum AnimalBehavior: Int, CaseIterable {
    case moving, energetic, coasting, resting
}

struct AnimalMotionPreset {
    let cruiseSpeed: Float
    let energeticSpeed: Float
    let acceleration: Float
    let planeLaneRadius: Float
    let roamLaneRadius: Float
    let gaitFrequency: Float
    let bobAmount: Float
    let bankAmount: Float
    let pitchAmount: Float
    let pulseAmount: Float
    let noiseAmplitude: Float
    let noiseFrequency: Float
    let altitudeScaleRange: ClosedRange<Float>
    let altitudeBounds: ClosedRange<Float>
    let roamAltitudeRange: ClosedRange<Float>
    let verticalAmplitudeScale: ClosedRange<Float>
    let verticalAmplitudeBounds: ClosedRange<Float>
    let depthRatio: Float
    let depthNoiseMultiplier: Float
    let turnaroundDuration: Float

    static func forLocomotion(_ locomotion: AnimalLocomotion) -> Self {
        switch locomotion {
        case .swim:
            Self(cruiseSpeed: 0.12, energeticSpeed: 0.25, acceleration: 0.72,
                 planeLaneRadius: 0.50, roamLaneRadius: 1.30, gaitFrequency: 3.8,
                 bobAmount: 0.012, bankAmount: 0.10, pitchAmount: 0.08,
                 pulseAmount: 0.025, noiseAmplitude: 0.012, noiseFrequency: 0.42,
                 altitudeScaleRange: 0.5...1.8, altitudeBounds: 0.12...0.80,
                 roamAltitudeRange: -0.10...0.35,
                 verticalAmplitudeScale: 0.15...0.30, verticalAmplitudeBounds: 0.03...0.12,
                 depthRatio: 0.06, depthNoiseMultiplier: 0.14, turnaroundDuration: 0.28)
        case .fly:
            Self(cruiseSpeed: 0.32, energeticSpeed: 0.65, acceleration: 1.45,
                 planeLaneRadius: 0.58, roamLaneRadius: 1.45, gaitFrequency: 5.6,
                 bobAmount: 0.018, bankAmount: 0.30, pitchAmount: 0.12,
                 pulseAmount: 0.040, noiseAmplitude: 0.014, noiseFrequency: 0.48,
                 altitudeScaleRange: 1.2...4.5, altitudeBounds: 0.35...1.80,
                 roamAltitudeRange: 0...0.75,
                 verticalAmplitudeScale: 0.20...0.45, verticalAmplitudeBounds: 0.06...0.18,
                 depthRatio: 0.08, depthNoiseMultiplier: 0.18, turnaroundDuration: 0.22)
        case .flutter:
            Self(cruiseSpeed: 0.11, energeticSpeed: 0.34, acceleration: 0.9,
                 planeLaneRadius: 0.42, roamLaneRadius: 1.05, gaitFrequency: 8.2,
                 bobAmount: 0.026, bankAmount: 0.24, pitchAmount: 0.12,
                 pulseAmount: 0.055, noiseAmplitude: 0.024, noiseFrequency: 1.05,
                 altitudeScaleRange: 0.8...3.2, altitudeBounds: 0.20...1.20,
                 roamAltitudeRange: 0...0.55,
                 verticalAmplitudeScale: 0.25...0.50, verticalAmplitudeBounds: 0.07...0.20,
                 depthRatio: 0.08, depthNoiseMultiplier: 0.18, turnaroundDuration: 0.22)
        case .walk:
            Self.grounded(cruise: 0.12, energetic: 0.46, acceleration: 1.6,
                          planeRadius: 0.44, roamRadius: 1.10, gait: 3.8, bob: 0.018,
                          bank: 0.09, pitch: 0.14, pulse: 0.032, noise: 0.009,
                          noiseFrequency: 0.55, depth: 0.04, turn: 0.28)
        case .stomp:
            Self.grounded(cruise: 0.075, energetic: 0.14, acceleration: 0.65,
                          planeRadius: 0.38, roamRadius: 0.98, gait: 2.0, bob: 0.012,
                          bank: 0.045, pitch: 0.075, pulse: 0.018, noise: 0.005,
                          noiseFrequency: 0.32, depth: 0.025, turn: 0.34)
        case .hop:
            Self.grounded(cruise: 0.05, energetic: 0.42, acceleration: 1.8,
                          planeRadius: 0.42, roamRadius: 1.05, gait: 2.7, bob: 0.09,
                          bank: 0.08, pitch: 0.12, pulse: 0.07, noise: 0.008,
                          noiseFrequency: 0.5, depth: 0.035, turn: 0.28)
        case .slither:
            Self.grounded(cruise: 0.095, energetic: 0.22, acceleration: 0.75,
                          planeRadius: 0.38, roamRadius: 0.96, gait: 3.2, bob: 0.006,
                          bank: 0.15, pitch: 0.035, pulse: 0.022, noise: 0.008,
                          noiseFrequency: 0.42, depth: 0.025, turn: 0.28)
        case .scuttle:
            Self.grounded(cruise: 0.09, energetic: 0.31, acceleration: 1.5,
                          planeRadius: 0.37, roamRadius: 0.94, gait: 6.5, bob: 0.008,
                          bank: 0.07, pitch: 0.045, pulse: 0.03, noise: 0.01,
                          noiseFrequency: 0.7, depth: 0.035, turn: 0.22)
        case .crawl:
            Self.grounded(cruise: 0.07, energetic: 0.20, acceleration: 1.05,
                          planeRadius: 0.36, roamRadius: 0.92, gait: 5.2, bob: 0.005,
                          bank: 0.055, pitch: 0.035, pulse: 0.02, noise: 0.008,
                          noiseFrequency: 0.62, depth: 0.03, turn: 0.26)
        case .waddle:
            Self.grounded(cruise: 0.065, energetic: 0.18, acceleration: 0.8,
                          planeRadius: 0.38, roamRadius: 0.96, gait: 3.1, bob: 0.022,
                          bank: 0.16, pitch: 0.06, pulse: 0.026, noise: 0.006,
                          noiseFrequency: 0.38, depth: 0.03, turn: 0.32)
        case .generic:
            Self.grounded(cruise: 0.055, energetic: 0.10, acceleration: 0.65,
                          planeRadius: 0.32, roamRadius: 0.82, gait: 1.8, bob: 0.006,
                          bank: 0.035, pitch: 0.035, pulse: 0.014, noise: 0.004,
                          noiseFrequency: 0.28, depth: 0.025, turn: 0.38)
        }
    }

    private static func grounded(
        cruise: Float, energetic: Float, acceleration: Float,
        planeRadius: Float, roamRadius: Float, gait: Float, bob: Float,
        bank: Float, pitch: Float, pulse: Float, noise: Float,
        noiseFrequency: Float, depth: Float, turn: Float
    ) -> Self {
        Self(cruiseSpeed: cruise, energeticSpeed: energetic, acceleration: acceleration,
             planeLaneRadius: planeRadius, roamLaneRadius: roamRadius, gaitFrequency: gait,
             bobAmount: bob, bankAmount: bank, pitchAmount: pitch, pulseAmount: pulse,
             noiseAmplitude: noise, noiseFrequency: noiseFrequency,
             altitudeScaleRange: 0...0, altitudeBounds: 0...0, roamAltitudeRange: 0...0,
             verticalAmplitudeScale: 0...0, verticalAmplitudeBounds: 0...0,
             depthRatio: depth, depthNoiseMultiplier: 0.08, turnaroundDuration: turn)
    }
}

struct MotionInstanceConfiguration {
    let cruiseSpeed: Float
    let energeticSpeed: Float
    let acceleration: Float
    let laneRadius: Float
    let baseAltitude: Float
    let verticalAmplitude: Float
    let altitudeBounds: ClosedRange<Float>
    let gaitFrequency: Float
    let bobAmount: Float
    let bankAmount: Float
    let pitchAmount: Float
    let pulseAmount: Float
    let noiseAmplitude: Float
    let noiseFrequency: Float
    let depthRatio: Float
    let depthNoiseMultiplier: Float
    let turnaroundDuration: Float
    let phaseOffset: Float
    let personality: Float
    let noiseSeed: Int32

    static func make(
        for locomotion: AnimalLocomotion,
        spawnMode: SpawnMode,
        physicalWidth: Float,
        seed: Int32 = .random(in: Int32.min...Int32.max)
    ) -> Self {
        let preset = AnimalMotionPreset.forLocomotion(locomotion)
        let random = GKLinearCongruentialRandomSource(seed: UInt64(UInt32(bitPattern: seed)))
        func unit() -> Float { Float(random.nextUniform()) }
        func sample(_ range: ClosedRange<Float>) -> Float {
            range.lowerBound + unit() * (range.upperBound - range.lowerBound)
        }
        func variation(_ value: Float, amount: Float = 0.1) -> Float {
            value * (1 + ((unit() * 2) - 1) * amount)
        }
        func clamp(_ value: Float, to range: ClosedRange<Float>) -> Float {
            min(max(value, range.lowerBound), range.upperBound)
        }

        let verticalAmplitude: Float
        let baseAltitude: Float
        let altitudeBounds: ClosedRange<Float>
        if locomotion.verticalStyle == .grounded {
            verticalAmplitude = 0
            baseAltitude = 0
            altitudeBounds = 0...0
        } else {
            verticalAmplitude = clamp(
                physicalWidth * sample(preset.verticalAmplitudeScale),
                to: preset.verticalAmplitudeBounds
            )
            if spawnMode == .cameraRoam {
                altitudeBounds = preset.roamAltitudeRange
                let highestBase = max(
                    preset.roamAltitudeRange.lowerBound,
                    preset.roamAltitudeRange.upperBound - verticalAmplitude
                )
                baseAltitude = min(sample(preset.roamAltitudeRange), highestBase)
            } else {
                altitudeBounds = preset.altitudeBounds
                let scaledAltitude = physicalWidth * sample(preset.altitudeScaleRange)
                let highestBase = max(
                    preset.altitudeBounds.lowerBound,
                    preset.altitudeBounds.upperBound - verticalAmplitude
                )
                baseAltitude = min(
                    max(scaledAltitude, preset.altitudeBounds.lowerBound),
                    highestBase
                )
            }
        }

        return Self(
            cruiseSpeed: variation(preset.cruiseSpeed),
            energeticSpeed: variation(preset.energeticSpeed),
            acceleration: variation(preset.acceleration),
            laneRadius: variation(spawnMode == .cameraRoam ? preset.roamLaneRadius : preset.planeLaneRadius, amount: 0.06),
            baseAltitude: baseAltitude,
            verticalAmplitude: verticalAmplitude,
            altitudeBounds: altitudeBounds,
            gaitFrequency: variation(preset.gaitFrequency),
            bobAmount: variation(preset.bobAmount),
            bankAmount: variation(preset.bankAmount),
            pitchAmount: variation(preset.pitchAmount),
            pulseAmount: variation(preset.pulseAmount),
            noiseAmplitude: variation(preset.noiseAmplitude),
            noiseFrequency: variation(preset.noiseFrequency),
            depthRatio: preset.depthRatio,
            depthNoiseMultiplier: preset.depthNoiseMultiplier,
            turnaroundDuration: preset.turnaroundDuration,
            phaseOffset: unit() * 2 * .pi,
            personality: 0.9 + unit() * 0.2,
            noiseSeed: seed
        )
    }
}
