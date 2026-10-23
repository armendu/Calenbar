//
//  EventKitAccessTests.swift
//  MeetingBarTests
//
//  Without full calendar access EventKit returns no calendars and no events
//  rather than an error, so the menu looked connected but empty. These tests
//  pin down what Calenbar does for each authorization status.
//

import Combine
import EventKit
import XCTest

@testable import Calenbar

@MainActor
final class EventKitAccessTests: BaseTestCase {
    func testFullAccessFetches() {
        XCTAssertEqual(EventKitAccess.action(for: .fullAccess), .proceed)
    }

    /// A new signature (every ad hoc build, including the DMG) makes macOS
    /// treat Calenbar as never asked, so access must be requested again.
    func testUndecidedAccessIsRequested() {
        XCTAssertEqual(EventKitAccess.action(for: .notDetermined), .request)
    }

    func testDeniedOrRestrictedAccessFails() {
        XCTAssertEqual(EventKitAccess.action(for: .denied), .fail(.notGranted))
        XCTAssertEqual(EventKitAccess.action(for: .restricted), .fail(.notGranted))
    }

    /// "Add Events Only" can't read events, so it must not count as access.
    func testWriteOnlyAccessFails() {
        XCTAssertEqual(EventKitAccess.action(for: .writeOnly), .fail(.writeOnly))
    }

    func testMissingAccessShowsPermissionRequired() {
        for error in [EventKitAccessError.notGranted, .writeOnly] {
            var appState = AppState()
            appState.activeProvider = .macOSEventKit
            appState.providerHealth = ProviderHealth.failure(
                previous: ProviderHealth(),
                attempted: Date(),
                error: CalendarSyncError.calendarAccessFailed(error)
            )

            let state = StatusBarMenuState.make(from: appState, settings: .empty)

            XCTAssertEqual(state.emptyStateReason, .permissionRequired, "\(error)")
            XCTAssertEqual(
                state.providerStatus,
                .permissionRequired(message: error.errorDescription),
                "\(error)"
            )
        }
    }

    /// After a successful refresh, revoked access still asks for permission
    /// rather than offering a refresh that can't help.
    func testRevokedAccessAfterSuccessShowsPermissionRequired() {
        var state = AppState()
        state.activeProvider = .macOSEventKit
        state.providerHealth = ProviderHealth.failure(
            previous: .success(attempted: Date(timeIntervalSince1970: 1_700_000_000)),
            attempted: Date(),
            error: CalendarSyncError.calendarAccessFailed(EventKitAccessError.notGranted)
        )

        XCTAssertEqual(
            PreferencesCalendarPresentation.make(from: state).connectionState,
            .permissionRequired
        )
        XCTAssertEqual(
            StatusBarMenuState.make(from: state, settings: .empty).emptyStateReason,
            .permissionRequired
        )
    }

    func testRefreshWithoutCalendarAccessReportsPermissionRequired() async {
        let store = FakeEventStore()
        store.stubbedCalendarError = EventKitAccessError.notGranted
        let manager = CalendarSync(provider: store, refreshInterval: 0)

        let exp = expectation(description: "failed refresh recorded")
        let cancellable = manager.$providerHealth
            .drop(while: { $0.lastAttemptedRefresh == nil })
            .first()
            .sink { health in
                XCTAssertTrue(health.permissionRequired)
                XCTAssertFalse(health.authRequired)
                exp.fulfill()
            }
        await fulfillment(of: [exp], timeout: 1.0)
        cancellable.cancel()
    }

    func testDiagnosticsReportWriteOnlyAccess() {
        XCTAssertEqual(PermissionReporter.calendarAccess(for: .writeOnly), .writeOnly)
        XCTAssertEqual(PermissionReporter.calendarAccess(for: .fullAccess), .authorized)
    }
}
