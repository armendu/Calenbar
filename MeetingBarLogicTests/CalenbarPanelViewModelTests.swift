//
//  CalenbarPanelViewModelTests.swift
//  MeetingBarLogicTests
//

// NOTE: As of this writing, this test file cannot compile inside the
// isolated `MeetingBarLogicTests` target — independently of the missing
// XCTest module in this environment. `CalenbarPanelViewModel`, `MBEvent`,
// `MBCalendar`, and `StatusBarMenuState` are not part of the `MeetingBarLogic`
// package: `MBEvent` pulls in `MBCalendar` (which stores an `NSColor`), and
// `StatusBarMenuState` pulls in `AppSettings`, which depends on the external
// `Defaults` package that this SPM target does not declare as a dependency.
// See the CalenbarPanelViewModel.swift header comment and the task's final
// report for the full explanation. This file documents the intended
// behavior of `CalenbarPanelViewModel.build(from:now:isFantasticalInstalled:)`
// and is written against the real, current initializers so it is ready to
// compile once that type-availability gap is deliberately resolved.

import AppKit
import XCTest

@testable import MeetingBarLogic

final class CalenbarPanelViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeCalendar(
        title: String = "Work",
        id: String = "cal-1",
        source: String? = "Test Source",
        email: String? = "user@example.com",
        color: NSColor = .systemBlue
    ) -> MBCalendar {
        MBCalendar(title: title, id: id, source: source, email: email, color: color)
    }

    private func makeEvent(
        id: String = "event-1",
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendar: MBCalendar? = nil
    ) -> MBEvent {
        MBEvent(
            id: id,
            lastModifiedDate: nil,
            title: title,
            status: .confirmed,
            notes: nil,
            location: nil,
            url: nil,
            organizer: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            recurrent: false,
            calendar: calendar ?? makeCalendar()
        )
    }

    private func makeState(
        nextEvent: MBEvent?,
        todayEvents: [MBEvent],
        timeFormat: TimeFormat = .military
    ) -> StatusBarMenuState {
        var state = StatusBarMenuState()
        state.nextEvent = nextEvent
        state.todayEvents = todayEvents
        state.timeFormat = timeFormat
        return state
    }

    func test_primarySection_withNextEvent_producesSummaryAndAgenda() {
        let next = makeEvent(
            title: "Stand Up",
            startDate: now.addingTimeInterval(4 * 60),
            endDate: now.addingTimeInterval(19 * 60)
        )
        let state = makeState(nextEvent: next, todayEvents: [next])

        let viewModel = CalenbarPanelViewModel.build(from: state, now: now, isFantasticalInstalled: false)

        XCTAssertEqual(viewModel.summary?.eventTitle, "Stand Up")
        XCTAssertEqual(viewModel.agenda.count, 1)
        XCTAssertEqual(viewModel.agenda.first?.title, "Stand Up")
        XCTAssertEqual(viewModel.agenda.first?.id, next.id)
        XCTAssertNil(viewModel.emptyStateMessage)
    }

    func test_primarySection_withNoUpcomingEvent_producesEmptyState() {
        let state = makeState(nextEvent: nil, todayEvents: [])
        let viewModel = CalenbarPanelViewModel.build(from: state, now: now, isFantasticalInstalled: false)
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.agenda.isEmpty)
        XCTAssertNotNil(viewModel.emptyStateMessage)
    }

    func test_agendaRow_marksCurrentlyRunningEventAsCurrent() {
        let running = makeEvent(
            id: "running",
            title: "Running Meeting",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(300)
        )
        let upcoming = makeEvent(
            id: "upcoming",
            title: "Later Meeting",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(5400)
        )
        let state = makeState(nextEvent: upcoming, todayEvents: [running, upcoming])

        let viewModel = CalenbarPanelViewModel.build(from: state, now: now, isFantasticalInstalled: false)

        let runningRow = viewModel.agenda.first { $0.id == "running" }
        let upcomingRow = viewModel.agenda.first { $0.id == "upcoming" }
        XCTAssertEqual(runningRow?.isCurrent, true)
        XCTAssertEqual(upcomingRow?.isCurrent, false)
    }

    func test_agendaRow_allDayEvent_usesAllDayTimeRangeText() {
        let allDay = makeEvent(
            id: "all-day",
            title: "Company Holiday",
            startDate: now,
            endDate: now.addingTimeInterval(86_400),
            isAllDay: true
        )
        let next = makeEvent(
            id: "next",
            title: "Kickoff",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1800)
        )
        let state = makeState(nextEvent: next, todayEvents: [allDay, next])

        let viewModel = CalenbarPanelViewModel.build(from: state, now: now, isFantasticalInstalled: false)

        let allDayRow = viewModel.agenda.first { $0.id == "all-day" }
        XCTAssertEqual(allDayRow?.timeRangeText, "status_bar_event_start_time_all_day".loco())
    }

    func test_agendaRow_untitledEvent_fallsBackToNoTitleLabel() {
        let untitled = makeEvent(
            id: "untitled",
            title: "",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1200)
        )
        let state = makeState(nextEvent: untitled, todayEvents: [untitled])

        let viewModel = CalenbarPanelViewModel.build(from: state, now: now, isFantasticalInstalled: false)

        XCTAssertEqual(viewModel.agenda.first?.title, "status_bar_no_title".loco())
    }
}
