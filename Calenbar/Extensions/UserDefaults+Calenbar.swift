//
//  UserDefaults+Calenbar.swift
//  Calenbar
//

import Foundation

extension UserDefaults {
    /// Domain the app-hosted test suite reads and writes instead of the app's
    /// bundle-ID domain (`dev.armendu.Calenbar`).
    static let calenbarTestSuiteName = "dev.armendu.Calenbar.tests"

    /// The store behind every Calenbar preference (`Defaults.Keys`, `@AppStorage`).
    ///
    /// The app uses `.standard`, i.e. the user's real preferences. When the app is
    /// hosting XCTest it uses a separate suite instead, so tests can never read,
    /// overwrite or wipe the user's settings.
    ///
    /// `nonisolated(unsafe)`: `UserDefaults` is thread-safe but not marked `Sendable`.
    nonisolated(unsafe) static let calenbar = calenbarStore(hostingTests: TestHostDetection.isHostingTests())

    static func calenbarStore(hostingTests: Bool) -> UserDefaults {
        guard hostingTests else { return .standard }
        guard let suite = UserDefaults(suiteName: calenbarTestSuiteName) else {
            preconditionFailure("Could not open the \(calenbarTestSuiteName) defaults suite")
        }
        return suite
    }
}

enum TestHostDetection {
    /// Whether this process is the host app of an XCTest run.
    ///
    /// The environment variables are set from process launch, so this is reliable
    /// even before the test bundle (and `XCTestCase`) has been loaded.
    static func isHostingTests(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        xctestLoaded: Bool = NSClassFromString("XCTestCase") != nil
    ) -> Bool {
        xctestLoaded
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}
