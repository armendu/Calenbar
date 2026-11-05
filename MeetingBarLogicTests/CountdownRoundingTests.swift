//
//  CountdownRoundingTests.swift
//  MeetingBarLogicTests
//
//  A meeting at 15:30 must read "in 1m" at any moment during 15:29, not
//  "in 0m": countdowns round the time left up to the next whole minute, so
//  they match the clock in the menu bar.
//

import XCTest

@testable import MeetingBarLogic

final class CountdownRoundingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-11-05 at the given time, UTC.
    private func date(_ hour: Int, _ minute: Int, _ second: Double = 0) -> Date {
        let whole = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: hour, minute: minute))!
        return whole.addingTimeInterval(second)
    }

    private func timeLeft(from now: Date, to end: Date) -> String {
        StatusBarTitlePolicy.formattedTimeLeft(from: now, to: end, calendar: calendar)
    }

    // MARK: - The 15:29 case

    func testMeetingAt1530ReadsOneMinuteThroughout1529() {
        let start = date(15, 30)
        for second in [0, 0.5, 30, 59, 59.9] {
            XCTAssertEqual(timeLeft(from: date(15, 29, second), to: start), "1m", "at 15:29:\(second)")
        }
    }

    func testMenuBarTitleAt1529SaysInOneMinute() {
        let start = date(15, 30)
        for second in [0, 30, 59.9] {
            let text = StatusBarTitlePolicy.text(
                eventTitle: "Standup",
                startDate: start,
                endDate: date(16, 0),
                settings: titleSettings,
                now: date(15, 29, second),
                calendar: calendar
            )
            XCTAssertEqual(text.time, "in 1m", "at 15:29:\(second)")
        }
    }

    func testPanelCountdownAt1529SaysInOneMinute() {
        let start = date(15, 30)
        let oneMinute = StatusBarTitlePolicy.formattedTimeLeft(
            from: start.addingTimeInterval(-60), to: start, calendar: .current
        )
        for second in [0, 30, 59.9] {
            let viewModel = panel(next: start, now: date(15, 29, second), thresholdEnabled: false)
            XCTAssertEqual(viewModel.summary?.countdown, "in \(oneMinute)", "at 15:29:\(second)")
        }
    }

    /// With the "only show events within N minutes" gate on, the panel shows
    /// "Next meeting • in …" instead of a card; it must round the same way.
    func testPanelNextMeetingLineRoundsUp() {
        let start = date(15, 30)
        let twoMinutes = StatusBarTitlePolicy.formattedTimeLeft(
            from: start.addingTimeInterval(-120), to: start, calendar: .current
        )
        let viewModel = panel(next: start, now: date(15, 28, 30), thresholdEnabled: true, thresholdMinutes: 1)
        XCTAssertEqual(viewModel.emptyStateMessage, "Next meeting • in \(twoMinutes)")
    }

    // MARK: - Boundaries

    /// Exactly on a minute boundary the time left is whole: 15:28:00 is
    /// 2 minutes before 15:30, not 3.
    func testExactMinuteBoundaryIsNotRoundedUp() {
        XCTAssertEqual(timeLeft(from: date(15, 28), to: date(15, 30)), "2m")
        XCTAssertEqual(timeLeft(from: date(15, 29), to: date(15, 30)), "1m")
    }

    func testJustOverAMinuteReadsTwoMinutes() {
        XCTAssertEqual(timeLeft(from: date(15, 28, 59), to: date(15, 30)), "2m")
    }

    func testHoursRoundUpByTheMinuteToo() {
        XCTAssertEqual(timeLeft(from: date(14, 29, 30), to: date(15, 30)), "1h 1m")
        XCTAssertEqual(timeLeft(from: date(14, 30), to: date(15, 30)), "1h")
    }

    /// A running meeting's "now (… left)" rounds the same way: 30 seconds
    /// before the end is "1m left", not "0m left".
    func testActiveMeetingTimeLeftRoundsUp() {
        let text = StatusBarTitlePolicy.text(
            eventTitle: "Standup",
            startDate: date(15, 0),
            endDate: date(15, 30),
            settings: titleSettings,
            now: date(15, 29, 30),
            calendar: calendar
        )
        XCTAssertTrue(text.isActiveEvent)
        XCTAssertEqual(text.time, "now (1m left)")
    }

    // MARK: - Helpers

    private var titleSettings: StatusBarTitleSettings {
        StatusBarTitleSettings(
            titleFormat: .show,
            titleLength: 55,
            labels: StatusBarTitleLabels(
                genericMeetingTitle: "Meeting",
                noTitle: "No title",
                activeEventTimeFormat: "now (%@ left)",
                upcomingEventTimeFormat: "in %@"
            )
        )
    }

    private func panel(
        next start: Date,
        now: Date,
        thresholdEnabled: Bool,
        thresholdMinutes: Int = 60
    ) -> CalenbarPanelViewModel {
        let event = CalenbarEventInput(
            id: "standup",
            title: "Standup",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            isAllDay: false,
            meetingService: nil,
            calendarEmail: nil,
            calendarSource: "Test Source",
            calendarTitle: "Work",
            organizerEmail: nil
        )
        let state = CalenbarPanelStateInput(
            nextEvent: event,
            todayEvents: [event],
            timeFormat: .twentyFourHour,
            showMaxTimeUntilEventEnabled: thresholdEnabled,
            showMaxTimeUntilEventThresholdMinutes: thresholdMinutes
        )
        return CalenbarPanelViewModel.build(
            from: state,
            now: now,
            locale: Locale(identifier: "en_US_POSIX"),
            labels: CalenbarPanelLabels(
                noTitle: "No title",
                currentMeetingSectionTitle: "Current meeting",
                nextMeetingSectionTitle: "Next meeting",
                countdownFormat: "in %@",
                allDayStartLabel: "All day",
                noUpcomingMessage: "No upcoming meetings"
            )
        )
    }
}
