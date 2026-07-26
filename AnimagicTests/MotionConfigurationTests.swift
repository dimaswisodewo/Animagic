//
//  MotionConfigurationTests.swift
//  AniMagicTests
//
//  Created by dimaswisodewo on 26/07/26.
//

import XCTest
@testable import AniMagic

final class MotionConfigurationTests: XCTestCase {
    func testEverySpeciesResolvesToSupportedProfile() {
        for species in DoodleSpecies.allCases {
            // Arrange
            let label = species.rawValue

            // Act
            let profile = AnimalMotionProfileResolver.profile(forLabel: label)

            // Assert
            XCTAssertTrue(AnimalLocomotion.allCases.contains(profile.locomotion))
        }
    }

    func testConfigurationBoundsRemainPositive() {
        for locomotion in AnimalLocomotion.allCases {
            // Arrange
            let physicalWidth: Float = 0.35

            // Act
            let configuration = MotionInstanceConfiguration.make(
                for: locomotion,
                spawnMode: .plane,
                physicalWidth: physicalWidth,
                seed: 1
            )

            // Assert
            XCTAssertGreaterThan(configuration.laneRadius, 0)
            XCTAssertGreaterThan(configuration.cruiseSpeed, 0)
        }
    }
}
