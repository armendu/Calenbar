//
//  ThisWeekMenuSectionTests.swift
//  MeetingBarTests
//

import AppKit
import Defaults
import XCTest

@testable import Calenbar

@MainActor
final class ThisWeekMenuSectionTests: BaseTestCase {
    private final class Dummy: NSObject {}

    private let later = Date().addingTimeInterval(2 * 86_400)

    private func event(_ id: String, startsIn offset: TimeInterval = 0, declined: Bool = false) -> MBEvent {
        let start = later.addingTimeInterval(offset)
        return makeFakeEvent(
            id: id,
            start: start,
            end: start.addingTimeInterval(1800),
            participationStatus: declined ? .declined : .accepted
        )
    }

    private func section(_ events: [MBEvent], limit: Int = 1) -> [NSMenuItem] {
        let state = StatusBarMenuState.make(from: events)
        return MenuBuilder(target: Dummy(), state: state)
            .buildNamedSection(title: "This week", events: events, limit: limit)
    }

    func test_emptyWeekAddsNothingToTheMenu() {
        XCTAssertTrue(section([]).isEmpty)
    }

    func test_headerNamesTheDayOfTheEvent() {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM"
        formatter.locale = I18N.instance.locale

        XCTAssertEqual(
            section([event("A")]).first?.title,
            "This week (\(formatter.string(from: later)))"
        )
    }

    func test_showsOnlyTheNextEvent() {
        let items = section([event("B", startsIn: 3600), event("A")])

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual((items[1].representedObject as? MBEvent)?.id, "A")
    }

    func test_hiddenFirstEventFallsThroughToTheNextVisibleOne() {
        Defaults[.declinedEventsAppereance] = .hide

        let items = section([event("declined", declined: true), event("visible", startsIn: 3600)])

        XCTAssertEqual((items.last?.representedObject as? MBEvent)?.id, "visible")
    }

    func test_onlyHiddenEventsAddNothing() {
        Defaults[.declinedEventsAppereance] = .hide

        XCTAssertTrue(section([event("declined", declined: true)]).isEmpty)
    }

    /// Wednesday noon, when Friday of the same week is still ahead. The menu
    /// state uses the user's calendar, so the week start can't be pinned.
    private func midweekWednesday() throws -> Date {
        let calendar = Calendar.current
        let wednesday = try XCTUnwrap(calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 12, weekday: 4),
            matchingPolicy: .nextTime
        ))
        let friday = wednesday.addingTimeInterval(2 * 86_400)
        try XCTSkipUnless(
            calendar.isDate(friday, equalTo: wednesday, toGranularity: .weekOfYear),
            "This locale's week ends before Friday"
        )
        return wednesday
    }

    func test_menuStateIncludesEventsFetchedForLaterThisWeek() throws {
        let wednesday = try midweekWednesday()
        let friday = makeFakeEvent(
            id: "fri",
            start: wednesday.addingTimeInterval(2 * 86_400),
            end: wednesday.addingTimeInterval(2 * 86_400 + 1800)
        )
        var appState = AppState()
        appState.laterThisWeekEvents = [friday]
        Defaults[.showEventsForPeriod] = .today_n_tomorrow

        let state = StatusBarMenuState.make(from: appState, settings: .current, now: wednesday)

        XCTAssertEqual(state.thisWeekEvents.map(\.id), ["fri"])
        XCTAssertNil(state.nextEvent, "Later events never become the next meeting")
    }

    func test_menuStateSkipsTomorrowWhenTomorrowHasItsOwnSection() throws {
        let wednesday = try midweekWednesday()
        let thursday = makeFakeEvent(
            id: "thu",
            start: wednesday.addingTimeInterval(86_400),
            end: wednesday.addingTimeInterval(86_400 + 1800)
        )
        let friday = makeFakeEvent(
            id: "fri",
            start: wednesday.addingTimeInterval(2 * 86_400),
            end: wednesday.addingTimeInterval(2 * 86_400 + 1800)
        )
        var appState = AppState()
        appState.events = [friday, thursday]

        Defaults[.showEventsForPeriod] = .today
        let todayOnly = StatusBarMenuState.make(from: appState, settings: .current, now: wednesday)
        Defaults[.showEventsForPeriod] = .today_n_tomorrow
        let withTomorrow = StatusBarMenuState.make(from: appState, settings: .current, now: wednesday)

        XCTAssertEqual(todayOnly.thisWeekEvents.map(\.id), ["thu", "fri"])
        XCTAssertEqual(withTomorrow.thisWeekEvents.map(\.id), ["fri"])
    }
}
