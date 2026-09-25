//
//  FakeEventStore.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.05.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//

import Foundation

@testable import Calenbar

final class FakeEventStore: AuthenticatedEventStore {
    nonisolated(unsafe) var stubbedCalendars: [MBCalendar]
    nonisolated(unsafe) var stubbedEvents: [MBEvent]
    nonisolated(unsafe) var stubbedError: Error?
    nonisolated(unsafe) var stubbedCalendarError: Error?
    nonisolated(unsafe) var stubbedEventsError: Error?
    nonisolated(unsafe) var stubbedSignInError: Error?
    nonisolated(unsafe) var fetchDelay: TimeInterval = 0
    /// When true, `fetchEventsForDateRange` honours the requested calendars
    /// (like a real provider) instead of returning every stubbed event.
    nonisolated(unsafe) var respectsCalendarFilter = false
    /// When true, `fetchEventsForDateRange` returns only events overlapping
    /// the requested range, like EventKit and Google do.
    nonisolated(unsafe) var respectsDateRange = false
    nonisolated(unsafe) private(set) var fetchedDateRanges: [(from: Date, to: Date)] = []
    nonisolated(unsafe) private(set) var fetchCallCount = 0
    nonisolated(unsafe) private(set) var fetchedEventCalendarIDs: [[String]] = []
    nonisolated(unsafe) private(set) var refreshSourcesCallCount = 0
    nonisolated(unsafe) private(set) var signInCallCount = 0
    nonisolated(unsafe) private(set) var signOutCallCount = 0
    nonisolated(unsafe) private(set) var cancelPendingOperationsCallCount = 0

    init(calendars: [MBCalendar] = [], events: [MBEvent] = []) {
        stubbedCalendars = calendars
        stubbedEvents = events
    }

    // MARK: - EventStore

    func fetchAllCalendars() async throws -> [MBCalendar] {
        fetchCallCount += 1
        if fetchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        }
        if let error = stubbedCalendarError { throw error }
        if let error = stubbedError { throw error }
        return stubbedCalendars
    }

    func fetchEventsForDateRange(
        for calendars: [MBCalendar],
        from dateFrom: Date,
        to dateTo: Date
    ) async throws -> [MBEvent] {
        fetchedEventCalendarIDs.append(calendars.map(\.id))
        fetchedDateRanges.append((dateFrom, dateTo))
        if let error = stubbedEventsError { throw error }
        if let error = stubbedError { throw error }
        var events = stubbedEvents
        if respectsDateRange {
            events = events.filter { $0.startDate < dateTo && $0.endDate > dateFrom }
        }
        guard respectsCalendarFilter else { return events }
        let requestedIDs = Set(calendars.map(\.id))
        return events.filter { requestedIDs.contains($0.calendar.id) }
    }

    func refreshSources() async {
        refreshSourcesCallCount += 1
    }

    func signIn(forcePrompt _: Bool) async throws {
        signInCallCount += 1
        if let error = stubbedSignInError { throw error }
    }

    func signOut() async {
        signOutCallCount += 1
    }

    @MainActor
    func cancelPendingOperations() {
        cancelPendingOperationsCallCount += 1
    }
}
