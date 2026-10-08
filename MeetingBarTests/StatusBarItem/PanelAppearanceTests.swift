//
//  PanelAppearanceTests.swift
//  MeetingBarTests
//

import AppKit
import SwiftUI
import XCTest

@testable import Calenbar

/// Unfocused windows turn accent colors grey; the panel and menu card shouldn't.
@MainActor
final class PanelAppearanceTests: BaseTestCase {
    private final class Probe {
        var appearsActive: Bool?
    }

    private struct ProbeView: View {
        let probe: Probe
        @Environment(\.appearsActive) private var appearsActive

        var body: some View {
            probe.appearsActive = appearsActive
            return Color.clear.frame(width: 10, height: 10)
        }
    }

    private func render(_ content: some View) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AnyView(content))
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(window.isKeyWindow)
        window.close()
    }

    func test_unfocusedWindowsAppearInactive() {
        let probe = Probe()
        render(ProbeView(probe: probe))
        XCTAssertEqual(probe.appearsActive, false, "reproduces the grey Join button")
    }

    func test_panelContentAppearsActiveInAnUnfocusedWindow() {
        let probe = Probe()
        render(ProbeView(probe: probe).calenbarAppearsActive())
        XCTAssertEqual(probe.appearsActive, true)
    }

    // Glass doesn't show up in captured images, so check the views set appearsActive.
    private func setsAppearsActive(_ view: Any, depth: Int = 0) -> Bool {
        guard depth < 12 else { return false }
        let children = Array(Mirror(reflecting: view).children)
        let keyPath = children.first { $0.label == "keyPath" }?.value as? AnyKeyPath
        let value = children.first { $0.label == "value" }?.value as? Bool
        if keyPath == \EnvironmentValues.appearsActive, value == true { return true }
        return children.contains { setsAppearsActive($0.value, depth: depth + 1) }
    }

    private let summary = MeetingSummaryPresentation(
        sectionTitle: "Next meeting", eventTitle: "Sync",
        metadata: ["10:00 – 10:30"], meetingService: .zoom, countdown: "in 5m"
    )

    func test_panelAppearsActive() {
        let panel = CalenbarGlassPanelView(
            viewModel: CalenbarPanelViewModel(summary: summary, agenda: [], emptyStateMessage: nil),
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )
        XCTAssertTrue(setsAppearsActive(panel.body))
    }

    func test_meetingCardAppearsActive() {
        XCTAssertTrue(setsAppearsActive(MeetingSummaryView(presentation: summary, onJoin: {}).body))
    }

    func test_viewsWithoutTheModifierAreNotDetected() {
        XCTAssertFalse(setsAppearsActive(Text("x").padding()))
    }
}
