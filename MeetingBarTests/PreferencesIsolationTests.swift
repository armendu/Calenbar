//
//  PreferencesIsolationTests.swift
//  MeetingBarTests
//
//  The test host is the real Calenbar.app, so preferences written through
//  `.standard` would land in the user's live `dev.armendu.Calenbar` domain.
//  These tests pin that every preference goes through `UserDefaults.calenbar`
//  and that, under XCTest, it is a separate suite.
//

import Defaults
import XCTest

@testable import Calenbar

final class PreferencesIsolationTests: BaseTestCase {
    private var appDomain: String {
        Bundle.main.bundleIdentifier!
    }

    func testTestHostUsesSuiteOtherThanAppDomain() {
        XCTAssertEqual(appDomain, "dev.armendu.Calenbar")
        XCTAssertNotEqual(UserDefaults.calenbarTestSuiteName, appDomain)
        XCTAssertFalse(UserDefaults.calenbar === UserDefaults.standard)
    }

    func testDefaultsKeysWriteToTestSuiteNotAppDomain() {
        let sentinel = "isolation-\(UUID().uuidString)"

        Defaults[.createMeetingServiceUrl] = sentinel

        let testSuite = UserDefaults.calenbar.persistentDomain(
            forName: UserDefaults.calenbarTestSuiteName)
        XCTAssertNotNil(testSuite?["createMeetingServiceUrl"])
        let appPrefs = UserDefaults.standard.persistentDomain(forName: appDomain) ?? [:]
        XCTAssertFalse(
            appPrefs.values.contains { ($0 as? String)?.contains(sentinel) == true },
            "A test write leaked into the app's real preferences"
        )
    }

    func testAppUsesStandardDefaultsOutsideTests() {
        XCTAssertTrue(UserDefaults.calenbarStore(hostingTests: false) === UserDefaults.standard)
        XCTAssertFalse(UserDefaults.calenbarStore(hostingTests: true) === UserDefaults.standard)
    }

    func testTestHostDetection() {
        XCTAssertTrue(TestHostDetection.isHostingTests(environment: [:], xctestLoaded: true))
        for variable in ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"] {
            XCTAssertTrue(
                TestHostDetection.isHostingTests(environment: [variable: "x"], xctestLoaded: false),
                variable
            )
        }
        XCTAssertFalse(TestHostDetection.isHostingTests(environment: [:], xctestLoaded: false))
    }

    @MainActor
    func testTestHostStatusItemsDoNotShareTheAppsAutosaveName() throws {
        let item = NSStatusBar.system.makeCalenbarStatusItem()
        defer { NSStatusBar.system.removeStatusItem(item) }

        let name = try XCTUnwrap(item.autosaveName)
        XCTAssertTrue(name.hasPrefix(NSStatusBar.testHostAutosaveNamePrefix), name)
    }

    // MARK: - Source checks

    func testEveryDefaultsKeyUsesCalenbarSuite() throws {
        let source = try String(
            contentsOf: Self.appSourceRoot.appendingPathComponent("Extensions/DefaultsKeys.swift"),
            encoding: .utf8
        )
        let declarations = source.components(separatedBy: "static let ").dropFirst()
            .filter { $0.contains("Key<") }

        XCTAssertFalse(declarations.isEmpty)
        for declaration in declarations where !declaration.contains("suite: .calenbar") {
            XCTFail("Defaults key must pass `suite: .calenbar`: \(declaration.prefix(80))")
        }
    }

    func testAppCodeDoesNotBypassCalenbarSuite() throws {
        let files = try XCTUnwrap(
            FileManager.default.enumerator(at: Self.appSourceRoot, includingPropertiesForKeys: nil)
        )
        for case let url as URL in files where url.pathExtension == "swift" {
            guard url.lastPathComponent != "UserDefaults+Calenbar.swift" else { continue }
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                let location = "\(url.lastPathComponent):\(index + 1)"
                XCTAssertFalse(
                    line.contains("UserDefaults.standard"),
                    "\(location) uses UserDefaults.standard; use UserDefaults.calenbar"
                )
                if line.contains("@AppStorage(") {
                    XCTAssertTrue(
                        line.contains("store: .calenbar"),
                        "\(location) needs `store: .calenbar` on @AppStorage"
                    )
                }
            }
        }
    }

    /// AppKit removes a status item's saved position from the app's real
    /// domain, so items must come from `makeCalenbarStatusItem()`.
    func testStatusItemsComeFromCalenbarFactory() throws {
        for root in [Self.appSourceRoot, Self.testSourceRoot] {
            let files = try XCTUnwrap(
                FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            )
            for case let url as URL in files where url.pathExtension == "swift" {
                let allowed = ["NSStatusBar+Calenbar.swift", "PreferencesIsolationTests.swift"]
                guard !allowed.contains(url.lastPathComponent) else { continue }
                XCTAssertFalse(
                    try String(contentsOf: url, encoding: .utf8).contains("statusItem(withLength"),
                    "\(url.lastPathComponent) creates a status item; use makeCalenbarStatusItem()"
                )
            }
        }
    }

    private static let testSourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    private static let appSourceRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Calenbar")
}
