//
//  BaseTestCase.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 28.05.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//

import XCTest
import Defaults

@testable import Calenbar

/// Gives each test empty preferences. Every `Defaults` key lives in
/// `UserDefaults.calenbar`, which under XCTest is a throwaway test suite, so
/// clearing it never touches the user's real `dev.armendu.Calenbar` domain.
class BaseTestCase: XCTestCase {

    private static let domain = UserDefaults.calenbarTestSuiteName

    override func setUp() {
        super.setUp()
        Self.clearTestDefaults()
    }

    override func tearDown() {
        Self.clearTestDefaults()
        super.tearDown()
    }

    private static func clearTestDefaults() {
        precondition(
            domain != Bundle.main.bundleIdentifier,
            "Refusing to clear the app's real preferences domain"
        )
        UserDefaults.calenbar.removePersistentDomain(forName: domain)
    }
}
