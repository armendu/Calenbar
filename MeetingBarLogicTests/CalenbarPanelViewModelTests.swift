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
        timeFormat: CalenbarTimeFormat = .twentyFourHour,
        showMaxTimeUntilEventEnabled: Bool = false,
        showMaxTimeUntilEventThresholdMinutes: Int = 60
    ) -> CalenbarPanelStateInput {
        CalenbarPanelStateInput(
            nextEvent: nextEvent,
            todayEvents: todayEvents,
            timeFormat: timeFormat,
            showMaxTimeUntilEventEnabled: showMaxTimeUntilEventEnabled,
            showMaxTimeUntilEventThresholdMinutes: showMaxTimeUntilEventThresholdMinutes
        )
    }

    private func build(_ state: CalenbarPanelStateInput) -> CalenbarPanelViewModel {
        CalenbarPanelViewModel.build(
            from: state,
            now: now,
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

    /// A finished event still appears in today's agenda (it's part of the
    /// day's history), but it must be flagged so the row can be rendered
    /// de-emphasized — otherwise it reads as equally "upcoming" as the
    /// still-future rows around it.
    func testPastEventInAgendaIsFlaggedAsHasEnded() {
        let next = makeEvent(
            id: "upcoming",
            title: "Upcoming",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(5400)
        )
        let past = makeEvent(
            id: "finished",
            title: "Finished",
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600)
        )
        let state = makeState(nextEvent: next, todayEvents: [next, past])

        let viewModel = build(state)

        let pastRow = viewModel.agenda.first { $0.id == past.id }
        XCTAssertEqual(pastRow?.hasEnded, true)
        let upcomingRow = viewModel.agenda.first { $0.id == next.id }
        XCTAssertNil(upcomingRow, "next event is excluded from the agenda — it's already the summary card")
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

    // MARK: - "show event max time until event" threshold

    /// Reported: the panel showed a meeting as the prominent summary card
    /// even though it was hours away. Mirrors
    /// StatusBarPresentationPolicy's existing .afterThreshold behavior for
    /// the status bar text — when the setting is enabled and the next event
    /// starts beyond the configured threshold, it shouldn't get the full
    /// summary treatment.
    func testEventBeyondThresholdIsNotShownAsSummary() {
        let farEvent = makeEvent(
            id: "far", title: "Quarterly Planning",
            startDate: now.addingTimeInterval(4 * 3600),
            endDate: now.addingTimeInterval(5 * 3600)
        )
        let state = makeState(
            nextEvent: farEvent, todayEvents: [farEvent],
            showMaxTimeUntilEventEnabled: true,
            showMaxTimeUntilEventThresholdMinutes: 60
        )

        let viewModel = build(state)

        XCTAssertNil(viewModel.summary)
        XCTAssertEqual(viewModel.emptyStateMessage, "Next meeting • in 4h")
    }

    /// The event isn't shown as the summary, but it hasn't vanished either —
    /// it's still listed in the agenda, since nowhere else on the panel
    /// shows it.
    func testEventBeyondThresholdStillAppearsInAgenda() {
        let farEvent = makeEvent(
            id: "far", title: "Quarterly Planning",
            startDate: now.addingTimeInterval(4 * 3600),
            endDate: now.addingTimeInterval(5 * 3600)
        )
        let state = makeState(
            nextEvent: farEvent, todayEvents: [farEvent],
            showMaxTimeUntilEventEnabled: true,
            showMaxTimeUntilEventThresholdMinutes: 60
        )

        let viewModel = build(state)

        XCTAssertEqual(viewModel.agenda.map(\.id), ["far"])
    }

    func testEventWithinThresholdIsStillShownAsSummary() {
        let soonEvent = makeEvent(
            id: "soon", title: "Stand Up",
            startDate: now.addingTimeInterval(20 * 60),
            endDate: now.addingTimeInterval(35 * 60)
        )
        let state = makeState(
            nextEvent: soonEvent, todayEvents: [soonEvent],
            showMaxTimeUntilEventEnabled: true,
            showMaxTimeUntilEventThresholdMinutes: 60
        )

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.eventTitle, "Stand Up")
        XCTAssertNil(viewModel.emptyStateMessage)
    }

    /// The setting defaults to disabled (matches
    /// DefaultsKeys.showEventMaxTimeUntilEventEnabled's default of false) —
    /// confirm a far-off event is still shown prominently when it's off,
    /// which is also `makeState`'s own default in this file.
    func testThresholdDisabledAlwaysShowsSummaryRegardlessOfDistance() {
        let farEvent = makeEvent(
            id: "far", title: "Quarterly Planning",
            startDate: now.addingTimeInterval(6 * 3600),
            endDate: now.addingTimeInterval(7 * 3600)
        )
        let state = makeState(nextEvent: farEvent, todayEvents: [farEvent])

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.eventTitle, "Quarterly Planning")
    }

    /// A currently-running event has a startDate in the past, so
    /// timeUntilStart is negative and can never be "beyond" a positive
    /// threshold — it must never be gated out by this check regardless of
    /// how long ago it started.
    func testRunningEventIsNeverGatedByThreshold() {
        let running = makeEvent(
            id: "running", title: "All-Hands",
            startDate: now.addingTimeInterval(-3 * 3600),
            endDate: now.addingTimeInterval(3600)
        )
        let state = makeState(
            nextEvent: running, todayEvents: [running],
            showMaxTimeUntilEventEnabled: true,
            showMaxTimeUntilEventThresholdMinutes: 60
        )

        let viewModel = build(state)

        XCTAssertEqual(viewModel.summary?.eventTitle, "All-Hands")
    }

    // MARK: - Badges

    private func row(isCurrent: Bool, service: MeetingServices?) -> CalenbarAgendaRow {
        CalenbarAgendaRow(
            id: "row",
            title: "Row",
            timeRangeText: "10:00 – 10:30",
            meetingService: service,
            isCurrent: isCurrent,
            hasEnded: false
        )
    }

    func testRunningEventBadgeIsLiveEvenWithAMeetingService() {
        XCTAssertEqual(row(isCurrent: true, service: .zoom).badge, .live(hasMeeting: true))
    }

    func testRunningEventWithoutAMeetingServiceIsLiveWithoutMeeting() {
        XCTAssertEqual(row(isCurrent: true, service: nil).badge, .live(hasMeeting: false))
    }

    func testUpcomingEventWithAMeetingServiceShowsTheService() {
        XCTAssertEqual(row(isCurrent: false, service: .meet).badge, .service(.meet))
    }

    func testUpcomingEventWithoutAMeetingServiceIsPlain() {
        XCTAssertEqual(row(isCurrent: false, service: nil).badge, .plain)
    }

    func testSummaryBadgeFollowsItsMeetingService() {
        let withService = MeetingSummaryPresentation(
            sectionTitle: "Next meeting", eventTitle: "Sync", metadata: [], meetingService: .teams
        )
        let without = MeetingSummaryPresentation(
            sectionTitle: "Next meeting", eventTitle: "Sync", metadata: [], meetingService: nil
        )

        XCTAssertEqual(withService.badge, .service(.teams))
        XCTAssertEqual(without.badge, .plain)
    }
}
