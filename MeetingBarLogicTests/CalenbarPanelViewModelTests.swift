//
//  CalenbarPanelViewModelTests.swift
//  MeetingBarLogicTests
//

import XCTest

@testable import MeetingBarLogic

final class CalenbarPanelViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private let labels = CalenbarPanelLabels(
        noTitle: "No title",
        currentMeetingSectionTitle: "Current meeting",
        nextMeetingSectionTitle: "Next meeting",
        countdownFormat: "in %@",
        allDayStartLabel: "All day",
        noUpcomingMessage: "No upcoming meetings"
    )

    private func locale() -> Locale {
        Locale(identifier: "en_US_POSIX")
    }

    private func makeEvent(
        id: String = "event-1",
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        meetingService: MeetingServices? = nil,
        calendarEmail: String? = "user@example.com",
        calendarSource: String = "Test Source",
        calendarTitle: String = "Work",
        organizerEmail: String? = nil
    ) -> CalenbarEventInput {
        CalenbarEventInput(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            meetingService: meetingService,
            calendarEmail: calendarEmail,
            calendarSource: calendarSource,
            calendarTitle: calendarTitle,
            organizerEmail: organizerEmail
        )
    }

    private func makeState(
        nextEvent: CalenbarEventInput?,
        todayEvents: [CalenbarEventInput],
        timeFormat: CalenbarTimeFormat = .twentyFourHour
    ) -> CalenbarPanelStateInput {
        CalenbarPanelStateInput(nextEvent: nextEvent, todayEvents: todayEvents, timeFormat: timeFormat)
    }

    private func build(_ state: CalenbarPanelStateInput) -> CalenbarPanelViewModel {
        CalenbarPanelViewModel.build(
            from: state,
            now: now,
            isFantasticalInstalled: false,
            locale: locale(),
            labels: labels
        )
    }

    func testPrimarySectionWithNextEventProducesSummaryAndAgenda() {
        let next = makeEvent(
            id: "standup",
            title: "Stand Up",
            startDate: now.addingTimeInterval(4 * 60),
            endDate: now.addingTimeInterval(19 * 60)
        )
        let later = makeEvent(
            id: "retro",
            title: "Retro",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(5400)
        )
        let state = makeState(nextEvent: next, todayEvents: [next, later])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.eventTitle, "Stand Up")
        XCTAssertEqual(viewModel.summary?.sectionTitle, "Next meeting")
        XCTAssertEqual(viewModel.agenda.count, 1)
        XCTAssertEqual(viewModel.agenda.first?.title, "Retro")
        XCTAssertEqual(viewModel.agenda.first?.id, later.id)
        XCTAssertNil(viewModel.emptyStateMessage)
    }

    /// The event already shown as the prominent summary card shouldn't also
    /// repeat as the first row of the agenda list below it — that's the
    /// same meeting rendered twice on screen for no reason.
    func testAgendaExcludesTheNextEventToAvoidDuplicatingTheSummaryCard() {
        let next = makeEvent(
            id: "only-event",
            title: "New Event",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1800)
        )
        let state = makeState(nextEvent: next, todayEvents: [next])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.eventTitle, "New Event")
        XCTAssertTrue(
            viewModel.agenda.isEmpty,
            "the only event today is already shown as the summary card; the agenda list should be empty, not repeat it"
        )
    }

    func testPrimarySectionWithNoUpcomingEventProducesEmptyState() {
        let state = makeState(nextEvent: nil, todayEvents: [])
        let viewModel = build(state)
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.agenda.isEmpty)
        XCTAssertEqual(viewModel.emptyStateMessage, "No upcoming meetings")
    }

    func testSummaryForCurrentlyRunningEventUsesCurrentMeetingTitleAndNoCountdown() {
        let running = makeEvent(
            title: "Standup",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(300)
        )
        let state = makeState(nextEvent: running, todayEvents: [running])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.sectionTitle, "Current meeting")
        XCTAssertNil(viewModel.summary?.countdown)
    }

    func testAgendaRowMarksCurrentlyRunningEventAsCurrent() {
        // A running event can't be "next" (nextEvent is always upcoming), so
        // it's a genuine agenda-list entry, not excluded like the summary's
        // own event is — a second, later event stands in for that excluded
        // "next" slot here.
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

        let viewModel = build(state)

        let runningRow = viewModel.agenda.first { $0.id == "running" }
        XCTAssertEqual(runningRow?.isCurrent, true)
        // "upcoming" is nextEvent, so it's excluded from the agenda list
        // (shown as the summary card instead) — confirm it's genuinely not
        // duplicated there, rather than silently asserting nothing about it.
        XCTAssertNil(viewModel.agenda.first { $0.id == "upcoming" })
    }

    func testAgendaRowAllDayEventUsesAllDayTimeRangeText() {
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

        let viewModel = build(state)

        let allDayRow = viewModel.agenda.first { $0.id == "all-day" }
        XCTAssertEqual(allDayRow?.timeRangeText, "All day")
    }

    func testAgendaRowUntitledEventFallsBackToNoTitleLabel() {
        let next = makeEvent(
            id: "next",
            title: "Kickoff",
            startDate: now.addingTimeInterval(300),
            endDate: now.addingTimeInterval(900)
        )
        let untitled = makeEvent(
            id: "untitled",
            title: "",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1200)
        )
        let state = makeState(nextEvent: next, todayEvents: [next, untitled])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.agenda.first?.title, "No title")
    }

    func testAgendaRowTimedEventUsesTwentyFourHourFormatWhenConfigured() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 14, minute: 30))!
        let end = start.addingTimeInterval(1800)
        let next = makeEvent(
            id: "next", title: "Kickoff",
            startDate: start.addingTimeInterval(-1800), endDate: start
        )
        let event = makeEvent(id: "timed", title: "Sync", startDate: start, endDate: end)
        let state = makeState(nextEvent: next, todayEvents: [next, event], timeFormat: .twentyFourHour)

        let viewModel = CalenbarPanelViewModel.build(
            from: state,
            now: start.addingTimeInterval(-3600),
            isFantasticalInstalled: false,
            locale: Locale(identifier: "en_US_POSIX"),
            labels: labels
        )

        // twentyFourHour uses "HH:mm" with the given locale/timezone-less
        // formatter (DateFormatter defaults to the system time zone), so we
        // only assert on the shape (no AM/PM marker) rather than an exact
        // wall-clock string that would be environment-dependent.
        let timeRangeText = viewModel.agenda.first?.timeRangeText ?? ""
        XCTAssertFalse(timeRangeText.contains("AM"))
        XCTAssertFalse(timeRangeText.contains("PM"))
    }
}
