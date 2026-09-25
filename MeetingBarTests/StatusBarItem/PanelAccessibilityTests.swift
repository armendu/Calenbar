//
//  PanelAccessibilityTests.swift
//  MeetingBarTests
//

import AppKit
import ApplicationServices
import SwiftUI
import XCTest

@testable import Calenbar

/// The panel's rows are tap-gesture views rather than `Button`s (for hover),
/// so VoiceOver only sees them as buttons if they say so. "More…" is the only
/// way into Preferences and Quit.
@MainActor
final class PanelAccessibilityTests: BaseTestCase {
    private let row = CalenbarAgendaRow(
        id: "1", title: "Design review", timeRangeText: "11:00 – 11:30",
        meetingService: .zoom, isCurrent: false, hasEnded: false
    )

    private func hostPanel(
        onJoin: @escaping () -> Void = {},
        onSelectAgendaRow: @escaping (CalenbarAgendaRow) -> Void = { _ in },
        onShowClassicMenu: @escaping () -> Void = {}
    ) -> NSView {
        let panel = CalenbarGlassPanelView(
            viewModel: CalenbarPanelViewModel(
                summary: MeetingSummaryPresentation(
                    sectionTitle: "Next meeting", eventTitle: "Weekly sync",
                    metadata: ["10:00 – 10:30"], meetingService: .zoom, countdown: "in 5m"
                ),
                agenda: [row],
                emptyStateMessage: nil
            ),
            onJoin: onJoin, onSelectAgendaRow: onSelectAgendaRow, onShowClassicMenu: onShowClassicMenu
        )
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        addTeardownBlock { @MainActor in window.close() }
        return host
    }

    /// SwiftUI only builds its accessibility tree for an assistive client, so
    /// the tests query this process through the Accessibility API like
    /// VoiceOver does. In-process requests run on the calling thread, which is
    /// the main thread here, as VoiceOver's are.
    private struct Element {
        let element: AXUIElement
        let role: String?
    }

    private func element(describedAs label: String) throws -> Element {
        func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
            var value: AnyObject?
            AXUIElementCopyAttributeValue(element, name as CFString, &value)
            return value
        }
        func find(_ element: AXUIElement) -> Element? {
            let description = attribute(element, kAXDescriptionAttribute) as? String
            if description?.contains(label) == true {
                return Element(element: element, role: attribute(element, kAXRoleAttribute) as? String)
            }
            let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
            return children.lazy.compactMap(find).first
        }
        return try XCTUnwrap(
            find(AXUIElementCreateApplication(getpid())),
            "No accessibility element described as \(label)"
        )
    }

    private func press(_ element: Element) -> AXError {
        AXUIElementPerformAction(element.element, kAXPressAction as CFString)
    }

    func test_moreRowIsAButtonThatOpensTheClassicMenu() throws {
        var opened = 0
        _ = hostPanel(onShowClassicMenu: { opened += 1 })

        let more = try element(describedAs: "calenbar_panel_more_accessibility_label".loco())

        XCTAssertEqual(more.role, kAXButtonRole)
        XCTAssertEqual(press(more), .success)
        XCTAssertEqual(opened, 1)
    }

    func test_agendaRowIsAButtonThatJoinsItsEvent() throws {
        var selected: [String] = []
        _ = hostPanel(onSelectAgendaRow: { selected.append($0.id) })

        let agendaRow = try element(describedAs: "Design review")

        XCTAssertEqual(agendaRow.role, kAXButtonRole)
        XCTAssertEqual(press(agendaRow), .success)
        XCTAssertEqual(selected, ["1"])
    }

    func test_summaryCardIsAButtonThatJoins() throws {
        var joined = 0
        _ = hostPanel(onJoin: { joined += 1 })

        let card = try element(describedAs: "Weekly sync")

        XCTAssertEqual(card.role, kAXButtonRole)
        XCTAssertEqual(press(card), .success)
        XCTAssertEqual(joined, 1)
    }
}
