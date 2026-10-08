//
//  PanelAppearanceTests.swift
//  MeetingBarTests
//

import AppKit
import SwiftUI
import XCTest

@testable import Calenbar

/// The panel never becomes the focused window, and SwiftUI draws controls in
/// an unfocused window as inactive: accent colors turn grey, Join included.
/// The panel's content should always look active, like Control Center's.
@MainActor
final class PanelAppearanceTests: BaseTestCase {
    private final class Probe: ObservableObject {
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

    /// Renders `content` in an on-screen window that isn't focused, like the panel.
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
        render(ProbeView(probe: probe).calenbarPanelAppearance())
        XCTAssertEqual(probe.appearsActive, true)
    }
}
