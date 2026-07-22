//
//  CutoutRigAnalyzerTests.swift
//  AniMagicTests
//
//  Created by Meynabel Dimas Wisodewo on 21/07/26.
//

import XCTest
@testable import AniMagic

final class CutoutRigAnalyzerTests: XCTestCase {
    func testAnalyzeAlphaCropsTransparentMarginsAndFindsSupportContacts() {
        // Arrange
        var alpha = [UInt8](repeating: 0, count: 100)
        for y in 3...7 {
            for x in 2...6 { alpha[y * 10 + x] = 255 }
        }

        // Act
        let descriptor = CutoutRigAnalyzer.analyzeAlpha(alpha, width: 10, height: 10)

        // Assert
        XCTAssertLessThan(descriptor.visibleBounds.width, 1)
        XCTAssertEqual(descriptor.supportContacts.count, 2)
    }

    func testAnalyzeAlphaUsesSafeFallbackForEmptyMask() {
        // Arrange
        let alpha = [UInt8](repeating: 0, count: 16)

        // Act
        let descriptor = CutoutRigAnalyzer.analyzeAlpha(alpha, width: 4, height: 4)

        // Assert
        XCTAssertEqual(descriptor.visibleBounds, CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(descriptor.facingConfidence, 0)
    }
}
