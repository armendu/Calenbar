//
//  PermissionReporter.swift
//  MeetingBar
//
//  Populates `PermissionSnapshot` (defined in `DiagnosticsReport.swift`) from
//  the real EventKit / UserNotifications APIs. Lives in the host target so
//  the hostless logic package can still depend on the snapshot type.
//

import EventKit
import Foundation
import UserNotifications

/// Whether this copy came from the App Store, for the diagnostics report.
enum AppSourceDetector {
    static func isAppStoreBuild(
        receiptURL: URL? = Bundle.main.appStoreReceiptURL,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> Bool {
        guard let receiptURL else { return false }
        return fileExists(receiptURL.path)
    }
}

enum PermissionReporter {
    @MainActor
    static func current(provider: EventStoreProvider) async -> PermissionSnapshot {
        let calendarAccess = calendarAuthStatus()
        let notificationAccess = await notificationAuthStatus()
        let googleAuthStatus: PermissionSnapshot.GoogleAuthStatus = provider == .googleCalendar
            ? (GCEventStore.shared.isAuthorized ? .authorized : .notAuthorized)
            : .notActive
        let scriptFileExists = scriptExists()
        let isAppStoreBuild = AppSourceDetector.isAppStoreBuild()
        return PermissionSnapshot(
            calendarAccess: calendarAccess,
            notificationAccess: notificationAccess,
            googleAuthStatus: googleAuthStatus,
            scriptFileExists: scriptFileExists,
            isAppStoreBuild: isAppStoreBuild
        )
    }

    private static func calendarAuthStatus() -> PermissionSnapshot.CalendarAccess {
        calendarAccess(for: EKEventStore.authorizationStatus(for: .event))
    }

    static func calendarAccess(for status: EKAuthorizationStatus) -> PermissionSnapshot.CalendarAccess {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .writeOnly: return .writeOnly
        case .fullAccess: return .authorized
        @unknown default: return .notDetermined
        }
    }

    private static func notificationAuthStatus() async -> PermissionSnapshot.NotificationAccess {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional, .ephemeral: return .provisional
        @unknown default: return .notDetermined
        }
    }

    private static func scriptExists() -> Bool {
        guard let dir = try? FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("eventStartScript.scpt").path)
    }
}
