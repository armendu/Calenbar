//
//  PanelLayoutTests.swift
//  MeetingBarTests
//

import AppKit
import SwiftUI
import XCTest

@testable import Calenbar

/// Guards the panel's and the classic menu rows' widths: both have stretched
/// to near screen width before when a view reported an unbounded ideal width.
@MainActor
final class PanelLayoutTests: BaseTestCase {
    private let longTitle = String(repeating: "Quarterly planning and roadmap review ", count: 6)

    private func summary(title: String) -> MeetingSummaryPresentation {
        MeetingSummaryPresentation(
            sectionTitle: "Next meeting",
            eventTitle: title,
            metadata: ["10:00 – 10:30", "Zoom", "work@example.com", "Work"],
            meetingService: .zoom,
            countdown: "in 5m"
        )
    }

    private func rows(_ count: Int) -> [CalenbarAgendaRow] {
        let kinds: [(MeetingServices?, Bool, Bool)] = [
            (.zoom, true, false),   // live
            (.meet, false, false),  // service
            (nil, false, false),    // plain
            (nil, false, true)      // ended
        ]
        return (0..<count).map { index in
            let (service, isCurrent, hasEnded) = kinds[index % kinds.count]
            return CalenbarAgendaRow(
                id: "\(index)", title: longTitle, timeRangeText: "11:00 – 11:30",
                meetingService: service, isCurrent: isCurrent, hasEnded: hasEnded
            )
        }
    }

    /// Opens the panel for `viewModel` and returns its frame.
    private func openPanelFrame(_ viewModel: CalenbarPanelViewModel) throws -> NSRect {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        let controller = CalenbarPanelController()
        defer { controller.dismiss() }
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))

        controller.toggle(
            near: button, viewModel: viewModel,
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )

        return try XCTUnwrap(NSApp.windows.first {
            $0 is NSPanel && !existing.contains(ObjectIdentifier($0))
        }).frame
    }

    // MARK: - Glass panel

    func test_panelKeepsItsFixedWidthWithLongContent() throws {
        let frame = try openPanelFrame(CalenbarPanelViewModel(
            summary: summary(title: longTitle), agenda: rows(4), emptyStateMessage: nil
        ))

        XCTAssertEqual(frame.width, CalenbarGlassPanelView.width)
    }

    func test_panelGrowsTallerForMoreAgendaRows() throws {
        let one = try openPanelFrame(CalenbarPanelViewModel(
            summary: summary(title: "Standup"), agenda: rows(1), emptyStateMessage: nil
        ))
        let four = try openPanelFrame(CalenbarPanelViewModel(
            summary: summary(title: "Standup"), agenda: rows(4), emptyStateMessage: nil
        ))

        XCTAssertGreaterThan(four.height, one.height)
    }

    // MARK: - Classic menu rows

    func test_summaryRowNeverAsksForMoreThanItsPreferredWidth() {
        let hosting = NSHostingView(rootView: MeetingSummaryView(presentation: summary(title: longTitle), onJoin: {}))

        XCTAssertLessThanOrEqual(hosting.fittingSize.width, MeetingSummaryView.preferredWidth)
    }

    func test_timelineRowHasTheMenuWidth() {
        let timeline = DayRelativeTimelineView(
            segments: [DaySegment(start: Date(), end: Date().addingTimeInterval(1800), color: .blue)],
            currentDate: Date(),
            timeFormat: .military
        )

        XCTAssertEqual(NSHostingView(rootView: timeline).fittingSize.width, MeetingSummaryView.preferredWidth)
    }
}
