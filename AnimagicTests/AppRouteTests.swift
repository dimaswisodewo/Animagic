//
//  AppRouteTests.swift
//  AniMagicTests
//
//  Created by dimaswisodewo on 26/07/26.
//

import XCTest
@testable import AniMagic

final class AppRouteTests: XCTestCase {
    func testDrawingDetailIdentityIncludesPayload() {
        // Arrange
        let firstID = UUID()
        let secondID = UUID()

        // Act
        let routes: Set<AppRoute> = [.drawingDetail(firstID), .drawingDetail(secondID)]

        // Assert
        XCTAssertEqual(routes.count, 2)
        XCTAssertEqual(AppRoute.arPlacement(initialCutoutID: firstID).id, .arPlacement(initialCutoutID: firstID))
    }
}
