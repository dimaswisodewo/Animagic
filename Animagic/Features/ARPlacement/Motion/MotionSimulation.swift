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
    var deformationActivity: Float
    var deformationPhase: Float
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

    mutating func update(
        deltaTime rawDeltaTime: Float,
        archetype: AnimalArchetype,
        configuration: MotionInstanceConfiguration,
        initialYaw: Float
    ) -> MotionSample {
        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 15.0)
        behaviorElapsed += deltaTime
        motionPhase += deltaTime * configuration.gaitFrequency * cadenceMultiplier
        if behaviorElapsed >= behaviorDuration {
            beginNextBehavior(archetype: archetype, configuration: configuration)
        }

        let noiseOffset = noise.offset(
            time: motionPhase * configuration.noiseFrequency,
            amplitude: configuration.noiseAmplitude
        )
        if !hasLaneTarget {
            chooseTarget(configuration: configuration)
        }
        var toTarget = target - position
        toTarget.y = 0
        if !isTurning, simd_length_squared(toTarget) < 0.0025 {
            isTurning = true
            turnElapsed = 0
        }
        if isTurning {
            turnElapsed += deltaTime
            if turnElapsed >= configuration.turnaroundDuration {
                isTurning = false
                chooseTarget(configuration: configuration)
            }
            toTarget = target - position
            toTarget.y = 0
        }

        let direction = safeNormalize(toTarget, fallback: [laneDirection, 0, 0])
        let desiredSpeed = isTurning ? 0 : speed(configuration: configuration)
        let targetVelocity = direction * desiredSpeed
        let velocityBlend = 1 - exp(-configuration.acceleration * deltaTime * 4)
        velocity += (targetVelocity - velocity) * velocityBlend
        position += velocity * deltaTime

        velocity += pathForce(archetype: archetype) * deltaTime * (isTurning ? 0.15 : 1)
        applyLaneLeash(configuration: configuration, deltaTime: deltaTime)
        applyVerticalMotion(
            archetype: archetype,
            configuration: configuration,
            noiseOffset: noiseOffset,
            deltaTime: deltaTime
        )
        position.x += noiseOffset.x * 0.18 * deltaTime
        position.z += noiseOffset.z * configuration.depthNoiseMultiplier * deltaTime

        let turnProgress = min(turnElapsed / max(configuration.turnaroundDuration, 0.001), 1)
        let visualDirection = isTurning && turnProgress >= 0.5 ? -laneDirection : laneDirection
        let travelYaw = initialYaw + (visualDirection < 0 ? .pi : 0)
        let turnDifference = atan2(sin(travelYaw - yaw), cos(travelYaw - yaw))
        yaw = travelYaw

        let normalizedSpeed = min(simd_length(velocity) / max(configuration.energeticSpeed, 0.001), 1)
        let gait = sin(motionPhase)
        let footfall = abs(gait)
        let desiredRoll = rollIntent(
            archetype: archetype,
            configuration: configuration,
            gait: gait,
            turnDifference: turnDifference,
            normalizedSpeed: normalizedSpeed
        )
        let verticalIntent = archetype.verticalStyle == .grounded ? -footfall : cos(motionPhase * 0.31)
        let behaviorPitch: Float = archetype == .cow && behavior == .resting ? 0.12 : 0
        let desiredPitch = min(max(
            verticalIntent * configuration.pitchAmount * normalizedSpeed + behaviorPitch,
            -.pi / 60
        ), .pi / 60)
        let clampedRoll = min(max(desiredRoll, -.pi / 18), .pi / 18)
        roll += (clampedRoll - roll) * min(deltaTime * 7, 1)
        pitch += (desiredPitch - pitch) * min(deltaTime * 7, 1)

        let stateProgress = min(behaviorElapsed / max(behaviorDuration, 0.001), 1)
        let compression = archetype == .rabbit && behavior == .energetic
            ? sin(stateProgress * .pi) * configuration.pulseAmount
            : footfall * configuration.pulseAmount * normalizedSpeed
        let turnScale: Float
        if isTurning {
            let fold = abs((turnProgress * 2) - 1)
            turnScale = 0.15 + smoothstep(fold) * 0.85
        } else {
            turnScale = 1
        }
        return MotionSample(
            position: position,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            scaleX: (1 + compression * 0.55) * turnScale,
            scaleY: (1 - compression) * (1 + (1 - turnScale) * 0.12),
            behavior: behavior,
            deformationActivity: deformationActivity * configuration.personality,
            deformationPhase: motionPhase
        )
    }

    private mutating func applyVerticalMotion(
        archetype: AnimalArchetype,
        configuration: MotionInstanceConfiguration,
        noiseOffset: SIMD3<Float>,
        deltaTime: Float
    ) {
        let stateProgress = min(behaviorElapsed / max(behaviorDuration, 0.001), 1)
        let footfall = abs(sin(motionPhase))
        switch archetype.verticalStyle {
        case .floating, .flying:
            let verticalFrequency: Float = archetype == .bird ? 0.22 : 0.31
            let oscillation = sin(motionPhase * verticalFrequency) * configuration.verticalAmplitude
                + noiseOffset.y
            let desiredAltitude = min(max(
                configuration.baseAltitude + oscillation,
                configuration.altitudeBounds.lowerBound
            ), configuration.altitudeBounds.upperBound)
            position.y += (desiredAltitude - position.y) * min(deltaTime * 3.2, 1)
        case .grounded:
            if (archetype == .rabbit || archetype == .cat), behavior == .energetic {
                let jumpScale: Float = archetype == .cat ? 4 : 1
                position.y = sin(stateProgress * .pi) * configuration.bobAmount * jumpScale
            } else {
                position.y = archetype == .snake
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

    private func pathForce(archetype: AnimalArchetype) -> SIMD3<Float> {
        let phase = motionPhase
        return switch archetype {
        case .fish: [0, 0, sin(phase * 0.72) * 0.055]
        case .bird: [0, 0, sin(phase * 0.77) * 0.09]
        case .butterfly: [sin(phase * 1.9) * 0.32, 0, sin(phase * 2.7) * 0.08]
        case .cat: [sin(phase * 0.55) * 0.25, 0, 0]
        case .cow: [sin(phase * 0.28) * 0.1, 0, 0]
        case .rabbit: [sin(phase * 0.9) * 0.2, 0, 0]
        case .snake: [sin(phase * 1.25) * 0.45, 0, 0]
        case .crab: [sin(phase * 0.8) * 0.16, 0, sin(phase * 0.8) * 0.025]
        case .generic: [sin(phase * 0.65) * 0.12, 0, sin(phase * 0.45) * 0.03]
        }
    }

    private func rollIntent(
        archetype: AnimalArchetype,
        configuration: MotionInstanceConfiguration,
        gait: Float,
        turnDifference: Float,
        normalizedSpeed: Float
    ) -> Float {
        if archetype == .bird {
            let turnBank = min(max(turnDifference / (.pi / 2), -1), 1)
            return -turnBank * configuration.bankAmount * normalizedSpeed
                - gait * configuration.bankAmount * 0.12 * normalizedSpeed
        }
        if archetype == .fish {
            return -gait * configuration.bankAmount * 0.35 * normalizedSpeed
        }
        return archetype.verticalStyle == .grounded
            ? gait * configuration.bankAmount * 0.3
            : -gait * configuration.bankAmount * normalizedSpeed
    }

    private var cadenceMultiplier: Float {
        switch behavior {
        case .moving: 1
        case .energetic: 1.75
        case .coasting: 0.55
        case .resting: 0.18
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
        archetype: AnimalArchetype,
        configuration: MotionInstanceConfiguration
    ) {
        let sequences: [AnimalArchetype: [AnimalBehavior]] = [
            .fish: [.moving, .moving, .coasting, .energetic],
            .bird: [.moving, .coasting, .moving, .energetic],
            .butterfly: [.energetic, .moving, .resting, .energetic],
            .cat: [.coasting, .resting, .moving, .energetic],
            .cow: [.moving, .resting, .coasting, .resting],
            .rabbit: [.resting, .energetic, .resting, .energetic],
            .snake: [.moving, .coasting, .resting, .moving],
            .crab: [.energetic, .resting, .moving, .energetic],
            .generic: [.moving, .coasting, .moving, .energetic]
        ]
        let sequence = sequences[archetype] ?? [.moving]
        transitionIndex = (transitionIndex + 1) % sequence.count
        behavior = sequence[transitionIndex]
        behaviorElapsed = 0
        let durationRange: ClosedRange<Float>
        switch behavior {
        case .moving: durationRange = 1.8...4.0
        case .energetic: durationRange = archetype == .rabbit ? 0.55...0.85 : 0.7...1.6
        case .coasting: durationRange = 1.2...3.0
        case .resting: durationRange = 0.8...2.6
        }
        behaviorDuration = randomFloat(in: durationRange) * configuration.personality
    }

    private mutating func chooseTarget(configuration: MotionInstanceConfiguration) {
        laneDirection *= -1
        hasLaneTarget = true
        let laneDistance = randomFloat(in: 0.72...0.94) * configuration.laneRadius
        let depthLimit = configuration.laneRadius * configuration.depthRatio
        target = [laneDirection * laneDistance, 0, randomFloat(in: -depthLimit...depthLimit)]
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
        deformationActivity: mix(from.deformationActivity, to.deformationActivity, t: amount),
        deformationPhase: mix(from.deformationPhase, to.deformationPhase, t: amount)
    )
}

private func mix(_ a: Float, _ b: Float, t: Float) -> Float { a + (b - a) * t }
