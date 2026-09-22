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

    func test_primarySection_withNextEvent_producesSummaryAndAgenda() {
        let next = makeEvent(
            title: "Stand Up",
            startDate: now.addingTimeInterval(4 * 60),
            endDate: now.addingTimeInterval(19 * 60)
        )
        let state = makeState(nextEvent: next, todayEvents: [next])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.eventTitle, "Stand Up")
        XCTAssertEqual(viewModel.summary?.sectionTitle, "Next meeting")
        XCTAssertEqual(viewModel.agenda.count, 1)
        XCTAssertEqual(viewModel.agenda.first?.title, "Stand Up")
        XCTAssertEqual(viewModel.agenda.first?.id, next.id)
        XCTAssertNil(viewModel.emptyStateMessage)
    }

    func test_primarySection_withNoUpcomingEvent_producesEmptyState() {
        let state = makeState(nextEvent: nil, todayEvents: [])
        let viewModel = build(state)
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.agenda.isEmpty)
        XCTAssertEqual(viewModel.emptyStateMessage, "No upcoming meetings")
    }

    func test_summary_forCurrentlyRunningEvent_usesCurrentMeetingTitleAndNoCountdown() {
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

        let viewModel = build(state)

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

        let viewModel = build(state)

        let allDayRow = viewModel.agenda.first { $0.id == "all-day" }
        XCTAssertEqual(allDayRow?.timeRangeText, "All day")
    }

    func test_agendaRow_untitledEvent_fallsBackToNoTitleLabel() {
        let untitled = makeEvent(
            id: "untitled",
            title: "",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1200)
        )
        let state = makeState(nextEvent: untitled, todayEvents: [untitled])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.agenda.first?.title, "No title")
    }

    func test_agendaRow_timedEvent_usesTwentyFourHourFormatWhenConfigured() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 14, minute: 30))!
        let end = start.addingTimeInterval(1800)
        let event = makeEvent(id: "timed", title: "Sync", startDate: start, endDate: end)
        let state = makeState(nextEvent: event, todayEvents: [event], timeFormat: .twentyFourHour)

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
