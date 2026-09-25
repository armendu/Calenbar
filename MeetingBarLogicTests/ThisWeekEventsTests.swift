//
//  ThisWeekEventsTests.swift
//  MeetingBarLogicTests
//

import XCTest

@testable import MeetingBarLogic

final class ThisWeekEventsTests: XCTestCase {
    private struct Event: Equatable {
        let id: String
        let start: Date
    }

    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private let mondayFirst = 2
    private let sundayFirst = 1

    /// 2026-09-<day> at the given hour, UTC. September 2026: Mon 21 … Sun 27, Mon 28.
    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        DateComponents(
            calendar: calendar(firstWeekday: mondayFirst),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        ).date!
    }

    private func thisWeek(
        _ events: [Event],
        now: Date,
        firstWeekday: Int = 2,
        skippingTomorrow: Bool = false
    ) -> [String] {
        EventSelection.thisWeekEvents(
            events,
            startDate: \.start,
            now: now,
            calendar: calendar(firstWeekday: firstWeekday),
            skippingTomorrow: skippingTomorrow
        ).map(\.id)
    }

    func testIncludesEventsFromTomorrowUntilTheWeekEnds() {
        let events = [
            Event(id: "thu", start: date(24, 9)),
            Event(id: "sun-late", start: date(27, 23, 59))
        ]

        XCTAssertEqual(thisWeek(events, now: date(23, 10)), ["thu", "sun-late"])
    }

    func testExcludesEventsStillToComeToday() {
        let events = [Event(id: "today-later", start: date(23, 18))]

        XCTAssertEqual(thisWeek(events, now: date(23, 10)), [])
    }

    func testExcludesEventsStartingAtOrAfterNextWeek() {
        let events = [
            Event(id: "next-monday-midnight", start: date(28, 0)),
            Event(id: "next-monday", start: date(28, 9))
        ]

        XCTAssertEqual(thisWeek(events, now: date(23, 10)), [])
    }

    func testSortsSoonestFirst() {
        let events = [
            Event(id: "sat", start: date(26, 9)),
            Event(id: "thu", start: date(24, 9)),
            Event(id: "fri", start: date(25, 9))
        ]

        XCTAssertEqual(thisWeek(events, now: date(23, 10)), ["thu", "fri", "sat"])
    }

    func testSkippingTomorrowLeavesTomorrowToItsOwnSection() {
        let events = [
            Event(id: "thu", start: date(24, 9)),
            Event(id: "fri", start: date(25, 9))
        ]

        XCTAssertEqual(thisWeek(events, now: date(23, 10), skippingTomorrow: true), ["fri"])
    }

    func testIsEmptyOnTheLastDayOfTheWeek() {
        let events = [Event(id: "next-monday", start: date(28, 9))]

        XCTAssertEqual(thisWeek(events, now: date(27, 10)), [])
    }

    func testIsEmptyWhenSkippingTomorrowAndTomorrowIsTheLastDay() {
        let events = [Event(id: "sun", start: date(27, 9))]

        XCTAssertEqual(thisWeek(events, now: date(26, 10), skippingTomorrow: true), [])
    }

    func testRespectsTheLocalesFirstWeekday() {
        let sunday = Event(id: "sun", start: date(27, 9))

        XCTAssertEqual(thisWeek([sunday], now: date(23, 10), firstWeekday: mondayFirst), ["sun"])
        XCTAssertEqual(thisWeek([sunday], now: date(23, 10), firstWeekday: sundayFirst), [])
    }

    // MARK: - Range

    private func range(now: Date, skippingTomorrow: Bool = false) -> Range<Date>? {
        EventSelection.thisWeekRange(
            now: now,
            calendar: calendar(firstWeekday: mondayFirst),
            skippingTomorrow: skippingTomorrow
        )
    }

    func testRangeRunsFromTomorrowToTheEndOfTheWeek() {
        XCTAssertEqual(range(now: date(23, 10)), date(24)..<date(28))
    }

    func testRangeStartsAfterTomorrowWhenTomorrowHasItsOwnSection() {
        XCTAssertEqual(range(now: date(23, 10), skippingTomorrow: true), date(25)..<date(28))
    }

    func testRangeIsNilWhenNothingOfTheWeekIsLeft() {
        XCTAssertNil(range(now: date(27, 10)))
        XCTAssertNil(range(now: date(26, 10), skippingTomorrow: true))
    }
}
