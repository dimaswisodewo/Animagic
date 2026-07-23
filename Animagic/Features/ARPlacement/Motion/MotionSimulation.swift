//
//  MotionSimulation.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation
import GameplayKit

struct MotionSample {
    var position: SIMD3<Float>
    var yaw: Float
    var pitch: Float
    var roll: Float
    var scaleX: Float
    var scaleY: Float
    var behavior: AnimalBehavior
    var behaviorProgress: Float
    var deformationActivity: Float
    var deformationPhase: Float
    var deformationIrregularity: Float
    var normalizedSpeed: Float
    var steering: Float
    var reactionProgress: Float
    var reactionStrength: Float
    var contact: Float
    var contactProgress: Float
    var attention: Float
}

enum AnimalMotionStimulus {
    case tapped
    case proximity(Float)
}

private enum MotionReaction {
    case tap
    case proximity
}

private struct OrganicNoiseField {
    private let xNoise: GKNoise
    private let yNoise: GKNoise
    private let zNoise: GKNoise

    init(seed: Int32) {
        xNoise = Self.makeNoise(seed: seed &+ 11)
        yNoise = Self.makeNoise(seed: seed &+ 23)
        zNoise = Self.makeNoise(seed: seed &+ 37)
    }

    func offset(time: Float, amplitude: Float) -> SIMD3<Float> {
        [sample(xNoise, time, 0.13), sample(yNoise, time, 1.37), sample(zNoise, time, 2.71)] * amplitude
    }

    private func sample(_ noise: GKNoise, _ time: Float, _ lane: Float) -> Float {
        noise.value(atPosition: vector_float2(time * 0.37 + lane, time * 0.11 + lane * 0.73))
    }

    private static func makeNoise(seed: Int32) -> GKNoise {
        GKNoise(GKPerlinNoiseSource(frequency: 1, octaveCount: 3, persistence: 0.5, lacunarity: 2, seed: seed))
    }
}

struct MotionSimulator {
    private var position: SIMD3<Float>
    private var velocity = SIMD3<Float>.zero
    private var target = SIMD3<Float>.zero
    private var yaw: Float
    private var pitch: Float = 0
    private var roll: Float = 0
    private var behavior: AnimalBehavior = .moving
    private var behaviorElapsed: Float = 0
    private var behaviorDuration: Float = 2
    private var motionPhase: Float
    private var transitionIndex = 0
    private var laneDirection: Float
    private var hasLaneTarget = false
    private var isTurning = false
    private var turnElapsed: Float = 0
    private var reactionElapsed: Float = 0
    private var reactionDuration: Float = 0
    private var reactionStrength: Float = 0
    private var reaction: MotionReaction?
    private var proximityCooldown: Float = 0
    private var previousGait: Float?
    private var contactElapsed: Float = 0.32
    private let random: GKRandomSource
    private let noise: OrganicNoiseField

    init(
        position: SIMD3<Float> = .zero,
        yaw: Float,
        configuration: MotionInstanceConfiguration,
        initialLaneDirection: Float = -1
    ) {
        self.position = position
        self.yaw = yaw
        laneDirection = initialLaneDirection
        motionPhase = configuration.phaseOffset
        random = GKLinearCongruentialRandomSource(seed: UInt64(UInt32(bitPattern: configuration.noiseSeed)))
        noise = OrganicNoiseField(seed: configuration.noiseSeed)
    }

    mutating func receive(
        _ stimulus: AnimalMotionStimulus,
        locomotion: AnimalLocomotion
    ) {
        switch stimulus {
        case .tapped:
            if locomotion == .hop {
                guard behavior != .energetic else { return }
                behavior = .energetic
                behaviorElapsed = 0
                behaviorDuration = 0.7
            }
            reactionDuration = locomotion.tapReactionDuration
            reactionStrength = 1
            reaction = .tap
        case .proximity(let distance):
            guard reactionElapsed >= reactionDuration, proximityCooldown <= 0 else { return }
            reactionDuration = 0.65
            reactionStrength = min(max((1.2 - distance) / 0.8, 0), 0.65)
            reaction = .proximity
            proximityCooldown = 2.5
        }
        reactionElapsed = 0
    }

    mutating func update(
        deltaTime rawDeltaTime: Float,
        locomotion: AnimalLocomotion,
        configuration: MotionInstanceConfiguration,
        initialYaw: Float
    ) -> MotionSample {
        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 15.0)
        reactionElapsed += deltaTime
        proximityCooldown = max(proximityCooldown - deltaTime, 0)
        let reactionProgress = min(reactionElapsed / max(reactionDuration, 0.001), 1)
        let reactionEnvelope = reactionElapsed < reactionDuration
            ? sin(reactionProgress * .pi) * reactionStrength
            : 0
        let dartProgress = reaction == .tap && reactionElapsed < reactionDuration
            ? reactionProgress
            : 0
        let dartStrength = reaction == .tap && reactionElapsed < reactionDuration
            ? reactionStrength
            : 0
        behaviorElapsed += deltaTime
        motionPhase += deltaTime * configuration.gaitFrequency * cadenceMultiplier
        if behaviorElapsed >= behaviorDuration {
            beginNextBehavior(locomotion: locomotion, configuration: configuration)
        }

        let noiseOffset = noise.offset(
            time: motionPhase * configuration.noiseFrequency,
            amplitude: configuration.noiseAmplitude
        )
        if !hasLaneTarget {
            chooseTarget(locomotion: locomotion, configuration: configuration)
        }
        var toTarget = target - position
        toTarget.y = 0
        if locomotion == .swim, simd_length_squared(toTarget) < 0.0081 {
            chooseTarget(locomotion: locomotion, configuration: configuration)
            toTarget = target - position
            toTarget.y = 0
        } else if !isTurning, simd_length_squared(toTarget) < 0.0025 {
            isTurning = true
            turnElapsed = 0
        }
        if isTurning {
            turnElapsed += deltaTime
            if turnElapsed >= configuration.turnaroundDuration {
                isTurning = false
                chooseTarget(locomotion: locomotion, configuration: configuration)
            }
            toTarget = target - position
            toTarget.y = 0
        }

        let direction = safeNormalize(toTarget, fallback: [laneDirection, 0, 0])
        let dartSpeedBoost = locomotion == .swim
            ? swimDartSpeedBoost(progress: dartProgress) * dartStrength
            : reactionEnvelope * 0.7
        let desiredSpeed = isTurning ? 0 : speed(configuration: configuration) * (1 + dartSpeedBoost)
        let targetVelocity = direction * desiredSpeed
        let steeringResponse: Float = locomotion == .swim ? 2.4 : 4
        let velocityBlend = 1 - exp(-configuration.acceleration * deltaTime * steeringResponse)
        velocity += (targetVelocity - velocity) * velocityBlend
        position += velocity * deltaTime

        velocity += pathForce(locomotion: locomotion) * deltaTime * (isTurning ? 0.15 : 1)
        applyLaneLeash(configuration: configuration, deltaTime: deltaTime)
        applyVerticalMotion(
            locomotion: locomotion,
            configuration: configuration,
            noiseOffset: noiseOffset,
            deltaTime: deltaTime
        )
        position.x += noiseOffset.x * 0.18 * deltaTime
        position.z += noiseOffset.z * configuration.depthNoiseMultiplier * deltaTime

        let turnProgress = min(turnElapsed / max(configuration.turnaroundDuration, 0.001), 1)
        let visualDirection = isTurning && turnProgress >= 0.5 ? -laneDirection : laneDirection
        let travelYaw: Float
        if locomotion == .swim {
            let travelDirection = safeNormalize(velocity, fallback: direction)
            travelYaw = initialYaw + atan2(-travelDirection.z, travelDirection.x)
        } else {
            travelYaw = initialYaw + (visualDirection < 0 ? .pi : 0)
        }
        let turnDifference = atan2(sin(travelYaw - yaw), cos(travelYaw - yaw))
        if locomotion == .swim {
            let yawBlend = 1 - exp(-deltaTime * 4.5)
            yaw += turnDifference * yawBlend
        } else {
            yaw = travelYaw
        }

        let normalizedSpeed = min(simd_length(velocity) / max(configuration.energeticSpeed, 0.001), 1)
        let steering = min(max(turnDifference / (.pi / 2), -1), 1)
        let gait = sin(motionPhase)
        let footfall = abs(gait)
        contactElapsed += deltaTime
        if let previousGait,
           (previousGait <= 0 && gait > 0) || (previousGait >= 0 && gait < 0) {
            contactElapsed = 0
        }
        previousGait = gait
        let contactProgress = min(contactElapsed / 0.32, 1)
        let desiredRoll = rollIntent(
            locomotion: locomotion,
            configuration: configuration,
            gait: gait,
            turnDifference: turnDifference,
            normalizedSpeed: normalizedSpeed
        )
        let verticalIntent = locomotion.verticalStyle == .grounded ? -footfall : cos(motionPhase * 0.31)
        let behaviorPitch: Float = locomotion == .stomp && behavior == .resting ? 0.12 : 0
        let desiredPitch = min(max(
            verticalIntent * configuration.pitchAmount * normalizedSpeed + behaviorPitch,
            -.pi / 60
        ), .pi / 60)
        let clampedRoll = min(max(desiredRoll, -.pi / 18), .pi / 18)
        roll += (clampedRoll - roll) * min(deltaTime * 7, 1)
        pitch += (desiredPitch - pitch) * min(deltaTime * 7, 1)

        let stateProgress = min(behaviorElapsed / max(behaviorDuration, 0.001), 1)
        let compression: Float
        if locomotion == .hop && behavior == .energetic {
            compression = 0
        } else if locomotion == .swim {
            compression = swimDartCompression(progress: dartProgress) * dartStrength
                + footfall * configuration.pulseAmount * normalizedSpeed * 0.35
        } else {
            let scaleContribution: Float = locomotion == .generic ? 0.5 : 1
            compression = footfall * configuration.pulseAmount
                * normalizedSpeed * scaleContribution
        }
        let turnScale: Float
        if isTurning {
            let fold = abs((turnProgress * 2) - 1)
            turnScale = 0.15 + smoothstep(fold) * 0.85
        } else {
            turnScale = 1
        }
        let scaleX: Float
        let scaleY: Float
        if locomotion == .swim {
            scaleX = (1 - compression * 0.65) * turnScale
            scaleY = (1 + compression * 0.35) * (1 + (1 - turnScale) * 0.12)
        } else {
            let reactionScale: Float = switch locomotion {
            case .hop: 0
            case .generic: 0.5
            default: 1
            }
            scaleX = (
                1 + compression * 0.55
                    + reactionEnvelope * 0.035 * reactionScale
            ) * turnScale
            scaleY = (1 - compression - reactionEnvelope * 0.055 * reactionScale)
                * (1 + (1 - turnScale) * 0.12)
        }
        return MotionSample(
            position: position,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            scaleX: scaleX,
            scaleY: scaleY,
            behavior: behavior,
            behaviorProgress: stateProgress,
            deformationActivity: deformationActivity * configuration.personality,
            deformationPhase: motionPhase,
            deformationIrregularity: configuration.noiseAmplitude > 0
                ? min(max(noiseOffset.x / configuration.noiseAmplitude, -1), 1)
                : 0,
            normalizedSpeed: normalizedSpeed,
            steering: steering,
            reactionProgress: dartProgress,
            reactionStrength: dartStrength,
            contact: locomotion.verticalStyle == .grounded ? 1 - min(footfall, 1) : 0,
            contactProgress: contactProgress,
            attention: reactionEnvelope
        )
    }

    private mutating func applyVerticalMotion(
        locomotion: AnimalLocomotion,
        configuration: MotionInstanceConfiguration,
        noiseOffset: SIMD3<Float>,
        deltaTime: Float
    ) {
        let stateProgress = min(behaviorElapsed / max(behaviorDuration, 0.001), 1)
        let footfall = abs(sin(motionPhase))
        switch locomotion.verticalStyle {
        case .floating, .flying:
            let verticalFrequency: Float = locomotion == .fly ? 0.22 : 0.31
            let deformationFocus: Float = locomotion == .fly || locomotion == .flutter
                ? 0.8
                : 1
            let oscillation = (
                sin(motionPhase * verticalFrequency) * configuration.verticalAmplitude
                    + noiseOffset.y
            ) * deformationFocus
            let desiredAltitude = min(max(
                configuration.baseAltitude + oscillation,
                configuration.altitudeBounds.lowerBound
            ), configuration.altitudeBounds.upperBound)
            position.y += (desiredAltitude - position.y) * min(deltaTime * 3.2, 1)
        case .grounded:
            if (locomotion == .hop || locomotion == .walk), behavior == .energetic {
                let jumpScale: Float = locomotion == .walk ? 4 : 1
                position.y = sin(stateProgress * .pi) * configuration.bobAmount * jumpScale
            } else {
                position.y = locomotion == .slither
                    ? max(noiseOffset.y * 0.08, 0)
                    : footfall * configuration.bobAmount
            }
        }
    }

    private mutating func applyLaneLeash(
        configuration: MotionInstanceConfiguration,
        deltaTime: Float
    ) {
        let horizontalDistance = simd_length(SIMD2<Float>(position.x, position.z))
        guard horizontalDistance > configuration.laneRadius * 0.98 else { return }
        let leash = SIMD3<Float>(position.x, 0, position.z) / max(horizontalDistance, 0.001)
        let excess = max(horizontalDistance - configuration.laneRadius * 0.98, 0)
        velocity -= leash * min(excess * configuration.acceleration * 3.5, configuration.acceleration) * deltaTime
        if horizontalDistance > configuration.laneRadius * 1.12 {
            position.x = leash.x * configuration.laneRadius * 1.12
            position.z = leash.z * configuration.laneRadius * 1.12
        }
    }

    private func pathForce(locomotion: AnimalLocomotion) -> SIMD3<Float> {
        let phase = motionPhase
        return switch locomotion {
        case .swim: [0, 0, sin(phase * 0.72) * 0.055]
        case .fly: [0, 0, sin(phase * 0.77) * 0.09]
        case .flutter: [sin(phase * 1.9) * 0.32, 0, sin(phase * 2.7) * 0.08]
        case .walk: [sin(phase * 0.55) * 0.25, 0, 0]
        case .stomp: [sin(phase * 0.28) * 0.1, 0, 0]
        case .hop: [sin(phase * 0.9) * 0.2, 0, 0]
        case .slither: [sin(phase * 1.25) * 0.45, 0, 0]
        case .scuttle: [sin(phase * 0.8) * 0.16, 0, sin(phase * 0.8) * 0.025]
        case .crawl: [sin(phase * 0.7) * 0.12, 0, sin(phase * 0.9) * 0.012]
        case .waddle: [sin(phase * 0.5) * 0.08, 0, 0]
        case .generic: [sin(phase * 0.35) * 0.035, 0, 0]
        }
    }

    private func rollIntent(
        locomotion: AnimalLocomotion,
        configuration: MotionInstanceConfiguration,
        gait: Float,
        turnDifference: Float,
        normalizedSpeed: Float
    ) -> Float {
        if locomotion == .fly {
            let turnBank = min(max(turnDifference / (.pi / 2), -1), 1)
            return -turnBank * configuration.bankAmount * normalizedSpeed
                - gait * configuration.bankAmount * 0.12 * normalizedSpeed
        }
        if locomotion == .swim {
            let turnBank = min(max(turnDifference / (.pi / 2), -1), 1)
            return -turnBank * configuration.bankAmount * normalizedSpeed
                - gait * configuration.bankAmount * 0.15 * normalizedSpeed
        }
        return locomotion.verticalStyle == .grounded
            ? gait * configuration.bankAmount * 0.3
            : -gait * configuration.bankAmount * normalizedSpeed
    }

    private var cadenceMultiplier: Float {
        switch behavior {
        case .moving: 1
        case .energetic: 1.75
        case .coasting: 0.75
        case .resting: 0.55
        }
    }

    private var deformationActivity: Float {
        switch behavior {
        case .moving: 0.8
        case .energetic: 1.15
        case .coasting: 0.35
        case .resting: 0.12
        }
    }

    private func speed(configuration: MotionInstanceConfiguration) -> Float {
        switch behavior {
        case .moving: configuration.cruiseSpeed
        case .energetic: configuration.energeticSpeed
        case .coasting: configuration.cruiseSpeed * 0.55
        case .resting: 0
        }
    }

    private mutating func beginNextBehavior(
        locomotion: AnimalLocomotion,
        configuration: MotionInstanceConfiguration
    ) {
        let sequences: [AnimalLocomotion: [AnimalBehavior]] = [
            .swim: [.moving, .moving, .coasting, .energetic],
            .fly: [.moving, .coasting, .moving, .energetic],
            .flutter: [.energetic, .moving, .resting, .energetic],
            .walk: [.coasting, .resting, .moving, .energetic],
            .stomp: [.moving, .resting, .coasting, .energetic],
            .hop: [.moving, .energetic, .resting, .energetic],
            .slither: [.moving, .coasting, .resting, .moving],
            .scuttle: [.energetic, .resting, .moving, .energetic],
            .crawl: [.moving, .coasting, .resting, .moving],
            .waddle: [.moving, .resting, .moving, .coasting],
            .generic: [.moving, .coasting, .resting, .moving]
        ]
        let sequence = sequences[locomotion] ?? [.moving]
        transitionIndex = (transitionIndex + 1) % sequence.count
        behavior = sequence[transitionIndex]
        behaviorElapsed = 0
        let durationRange: ClosedRange<Float>
        switch behavior {
        case .moving: durationRange = 1.8...4.0
        case .energetic: durationRange = locomotion == .hop ? 0.55...0.85 : 0.7...1.6
        case .coasting: durationRange = 1.2...3.0
        case .resting: durationRange = 0.35...0.9
        }
        let personalityDuration = randomFloat(in: durationRange) * configuration.personality
        behaviorDuration = behavior == .resting
            ? min(max(personalityDuration, 0.35), 0.9)
            : personalityDuration
    }

    private mutating func chooseTarget(
        locomotion: AnimalLocomotion,
        configuration: MotionInstanceConfiguration
    ) {
        laneDirection *= -1
        hasLaneTarget = true
        if locomotion == .swim {
            let horizontalDirection = safeNormalize(
                SIMD3<Float>(velocity.x, 0, velocity.z),
                fallback: [laneDirection, 0, 0]
            )
            let forwardAngle = atan2(horizontalDirection.z, horizontalDirection.x)
            let turnAngle = randomFloat(in: (.pi * 0.28)...(.pi * 0.62))
                * (random.nextBool() ? 1 : -1)
            let targetAngle = forwardAngle + turnAngle
            let radius = randomFloat(in: 0.58...0.88) * configuration.laneRadius
            let depthRadius = configuration.laneRadius * configuration.depthRatio
            target = [
                cos(targetAngle) * radius,
                0,
                sin(targetAngle) * depthRadius
            ]
            return
        }
        let laneDistance = randomFloat(in: 0.72...0.94) * configuration.laneRadius
        let depthLimit = configuration.laneRadius * configuration.depthRatio
        target = [laneDirection * laneDistance, 0, randomFloat(in: -depthLimit...depthLimit)]
    }

    private func swimDartSpeedBoost(progress: Float) -> Float {
        guard progress > 0 else { return 0 }
        if progress < 0.133 {
            return 0
        }
        if progress < 0.444 {
            return sin((progress - 0.133) / 0.311 * .pi) * 1.25
        }
        return (1 - smoothstep((progress - 0.444) / 0.556)) * 0.32
    }

    private func swimDartCompression(progress: Float) -> Float {
        guard progress > 0 else { return 0 }
        if progress < 0.133 {
            return smoothstep(progress / 0.133) * 0.075
        }
        if progress < 0.444 {
            return -(sin((progress - 0.133) / 0.311 * .pi) * 0.035)
        }
        return sin((progress - 0.444) / 0.556 * .pi * 3) * (1 - progress) * 0.025
    }

    private func randomFloat(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + Float(random.nextUniform()) * (range.upperBound - range.lowerBound)
    }
}

func safeNormalize(_ value: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
    simd_length_squared(value) > 0.000001 ? simd_normalize(value) : fallback
}

func smoothstep(_ value: Float) -> Float {
    let clamped = min(max(value, 0), 1)
    return clamped * clamped * (3 - 2 * clamped)
}

func blend(from: MotionSample, to: MotionSample, amount: Float) -> MotionSample {
    let yawDifference = atan2(sin(to.yaw - from.yaw), cos(to.yaw - from.yaw))
    return MotionSample(
        position: simd_mix(from.position, to.position, SIMD3<Float>(repeating: amount)),
        yaw: from.yaw + yawDifference * amount,
        pitch: mix(from.pitch, to.pitch, t: amount),
        roll: mix(from.roll, to.roll, t: amount),
        scaleX: mix(from.scaleX, to.scaleX, t: amount),
        scaleY: mix(from.scaleY, to.scaleY, t: amount),
        behavior: to.behavior,
        behaviorProgress: mix(from.behaviorProgress, to.behaviorProgress, t: amount),
        deformationActivity: mix(from.deformationActivity, to.deformationActivity, t: amount),
        deformationPhase: mix(from.deformationPhase, to.deformationPhase, t: amount),
        deformationIrregularity: mix(
            from.deformationIrregularity,
            to.deformationIrregularity,
            t: amount
        ),
        normalizedSpeed: mix(from.normalizedSpeed, to.normalizedSpeed, t: amount),
        steering: mix(from.steering, to.steering, t: amount),
        reactionProgress: mix(from.reactionProgress, to.reactionProgress, t: amount),
        reactionStrength: mix(from.reactionStrength, to.reactionStrength, t: amount),
        contact: mix(from.contact, to.contact, t: amount),
        contactProgress: mix(from.contactProgress, to.contactProgress, t: amount),
        attention: mix(from.attention, to.attention, t: amount)
    )
}

private extension AnimalLocomotion {
    var tapReactionDuration: Float {
        switch self {
        case .swim: 0.9
        case .fly: 0.7
        case .flutter: 0.6
        case .walk: 0.65
        case .stomp: 0.65
        case .waddle: 0.75
        case .hop: 0.7
        case .slither: 0.8
        case .crawl: 0.7
        case .scuttle: 0.65
        case .generic: 0.6
        }
    }
}

private func mix(_ a: Float, _ b: Float, t: Float) -> Float { a + (b - a) * t }
