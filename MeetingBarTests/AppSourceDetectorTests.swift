//
//  AppSourceDetectorTests.swift
//  MeetingBarTests
//

import XCTest

@testable import Calenbar

final class AppSourceDetectorTests: XCTestCase {
    func testAppSourceDetectorRequiresReceiptFile() {
        let receiptURL = URL(fileURLWithPath: "/tmp/receipt")

        XCTAssertTrue(AppSourceDetector.isAppStoreBuild(
            receiptURL: receiptURL,
            fileExists: { $0 == receiptURL.path }
        ))
        XCTAssertFalse(AppSourceDetector.isAppStoreBuild(
            receiptURL: receiptURL,
            fileExists: { _ in false }
        ))
        XCTAssertFalse(AppSourceDetector.isAppStoreBuild(
            receiptURL: nil,
            fileExists: { _ in true }
        ))
    }
}
