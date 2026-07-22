//
//  MotionSimulatorTests.swift
//  AniMagicTests
//
//  Created by Meynabel Dimas Wisodewo on 21/07/26.
//

import XCTest
@testable import AniMagic

final class MotionSimulatorTests: XCTestCase {
    func testEveryLocomotionProducesFiniteBoundedSamples() {
        for locomotion in AnimalLocomotion.allCases {
            // Arrange
            let configuration = MotionInstanceConfiguration.make(
                for: locomotion,
                spawnMode: .plane,
                physicalWidth: 0.35,
                seed: 42
            )
            var simulator = MotionSimulator(yaw: 0, configuration: configuration)

            // Act
            let samples = (0..<600).map { _ in
                simulator.update(
                    deltaTime: 1 / 60,
                    locomotion: locomotion,
                    configuration: configuration,
                    initialYaw: 0
                )
            }

            // Assert
            XCTAssertTrue(samples.allSatisfy { sample in
                sample.position.x.isFinite && sample.position.y.isFinite && sample.position.z.isFinite &&
                sample.scaleX.isFinite && sample.scaleY.isFinite &&
                abs(sample.position.x) <= configuration.laneRadius * 1.13 &&
                abs(sample.position.z) <= configuration.laneRadius * 1.13
            }, "Invalid sample for \(locomotion)")
        }
    }

    func testTapProducesAttentionWithoutResettingPhase() {
        // Arrange
        let configuration = MotionInstanceConfiguration.make(
            for: .walk,
            spawnMode: .plane,
            physicalWidth: 0.35,
            seed: 7
        )
        var simulator = MotionSimulator(yaw: 0, configuration: configuration)
        let before = simulator.update(
            deltaTime: 1 / 60,
            locomotion: .walk,
            configuration: configuration,
            initialYaw: 0
        )

        // Act
        simulator.receive(.tapped)
        let after = simulator.update(
            deltaTime: 1 / 60,
            locomotion: .walk,
            configuration: configuration,
            initialYaw: 0
        )

        // Assert
        XCTAssertGreaterThan(after.attention, 0)
        XCTAssertGreaterThan(after.deformationPhase, before.deformationPhase)
    }
}
