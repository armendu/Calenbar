//
//  EventKitAccess.swift
//  Calenbar
//

import EventKit

/// Why Calenbar can't read macOS calendars. Thrown from a fetch so the menu
/// and Preferences show "permission required" instead of an empty agenda:
/// without full access EventKit returns no calendars rather than an error.
enum EventKitAccessError: LocalizedError, Equatable {
    case notGranted
    case writeOnly

    var errorDescription: String? {
        switch self {
        case .notGranted:
            return "Calenbar doesn't have access to your calendars"
        case .writeOnly:
            return "Calenbar can only add events to your calendars, not read them"
        }
    }
}

enum EventKitAccess {
    enum Action: Equatable {
        case proceed
        case request
        case fail(EventKitAccessError)
    }

    /// What a fetch does for the current authorization status. macOS ties the
    /// grant to the app's signature, so an ad hoc build (the DMG included) is
    /// often `.notDetermined` again and has to ask.
    static func action(for status: EKAuthorizationStatus) -> Action {
        switch status {
        case .fullAccess:
            return .proceed
        case .notDetermined:
            return .request
        case .writeOnly:
            return .fail(.writeOnly)
        case .denied, .restricted:
            return .fail(.notGranted)
        @unknown default:
            return .proceed
        }
    }
}

/// Checks calendar access before a fetch, asking macOS when it hasn't decided.
/// The status and the request are injectable so tests can drive every case
/// through the real `fetchAllCalendars()`.
struct EventKitAccessGate: Sendable {
    var status: @Sendable () -> EKAuthorizationStatus
    var requestAccess: @Sendable () async throws -> Void

    static let live = EventKitAccessGate(
        status: { EKEventStore.authorizationStatus(for: .event) },
        requestAccess: { try await EKEventStore.shared.signIn() }
    )

    func ensureAccess() async throws {
        switch EventKitAccess.action(for: status()) {
        case .proceed:
            return
        case .request:
            try await requestAccess()
        case let .fail(error):
            throw error
        }
    }
}
