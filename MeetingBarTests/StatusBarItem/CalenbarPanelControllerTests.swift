//
//  CalenbarPanelControllerTests.swift
//  MeetingBarTests
//

import XCTest
@testable import Calenbar

@MainActor
final class CalenbarPanelControllerTests: BaseTestCase {
    private func makeButton() -> (NSStatusItem, NSStatusBarButton) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else {
            XCTFail("expected NSStatusItem to vend a button")
            return (item, NSStatusBarButton())
        }
        return (item, button)
    }

    private func makeViewModel(emptyStateMessage: String = "No upcoming meetings") -> CalenbarPanelViewModel {
        CalenbarPanelViewModel(summary: nil, agenda: [], emptyStateMessage: emptyStateMessage)
    }

    /// A row hovered when the panel closes must still get its hover-off, or
    /// its pointing-hand cursor stays pushed.
    func test_dismissEndsHoverOnRowsInsideThePanel() throws {
        let (item, button) = makeButton()
        defer { NSStatusBar.system.removeStatusItem(item) }
        let controller = CalenbarPanelController()
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.toggle(
            near: button, viewModel: makeViewModel(),
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )
        let panel = try XCTUnwrap(NSApp.windows.first {
            $0 is NSPanel && !existingWindows.contains(ObjectIdentifier($0))
        })
        let row = CalenbarHoverTrackingView()
        var hoverChanges: [Bool] = []
        row.onChange = { hoverChanges.append($0) }
        panel.contentView?.addSubview(row)
        row.mouseEntered(with: try XCTUnwrap(NSEvent.enterExitEvent(
            with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
        )))

        controller.dismiss()

        XCTAssertEqual(hoverChanges, [true, false])
        XCTAssertFalse(row.isShowingPointingHand)
    }

    func test_toggleShowsPanel() {
        let (item, button) = makeButton()
        defer { NSStatusBar.system.removeStatusItem(item) }
        let controller = CalenbarPanelController()

        XCTAssertFalse(controller.isVisible)
        controller.toggle(
            near: button, viewModel: makeViewModel(),
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )
        XCTAssertTrue(controller.isVisible)

        controller.dismiss()
    }

    func test_toggleTwiceDismissesRatherThanReopening() {
        let (item, button) = makeButton()
        defer { NSStatusBar.system.removeStatusItem(item) }
        let controller = CalenbarPanelController()

        controller.toggle(
            near: button, viewModel: makeViewModel(),
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )
        XCTAssertTrue(controller.isVisible)

        // A second toggle (mirroring a second left-click on the status item
        // while the panel is already open) should close it, matching
        // NSMenu.popUp's click-to-toggle behavior.
        controller.toggle(
            near: button, viewModel: makeViewModel(),
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )
        XCTAssertFalse(controller.isVisible)
    }

    func test_dismissIsIdempotent() {
        let controller = CalenbarPanelController()
        XCTAssertFalse(controller.isVisible)
        controller.dismiss()
        controller.dismiss()
        XCTAssertFalse(controller.isVisible)
    }

    /// Regression test for the bug reported as "the app quits" when tapping
    /// the panel's "More…" row. It wasn't actually crashing: `openMenu()`'s
    /// `performClick(nil)` blocks for as long as the classic NSMenu is
    /// tracking, and the glass panel used to stay open that whole time
    /// because `dismiss()` ran *after* the callback instead of before — two
    /// floating panels stacked on screen at once, with "Quit Calenbar"
    /// sitting right where someone reaching to dismiss the confusion would
    /// click. `dismissThenPerform` is the extracted, directly-testable unit
    /// that now enforces the correct order; this asserts it holds without
    /// needing a live NSPanel or NSStatusBarButton.
    func test_dismissThenPerformDismissesBeforeInvokingAction() {
        let (item, button) = makeButton()
        defer { NSStatusBar.system.removeStatusItem(item) }
        let controller = CalenbarPanelController()

        controller.toggle(
            near: button, viewModel: makeViewModel(),
            onJoin: {}, onSelectAgendaRow: { _ in }, onShowClassicMenu: {}
        )
        XCTAssertTrue(controller.isVisible)

        var wasVisibleWhenActionFired: Bool?
        controller.dismissThenPerform {
            wasVisibleWhenActionFired = controller.isVisible
        }

        XCTAssertEqual(wasVisibleWhenActionFired, false)
        XCTAssertFalse(controller.isVisible)
    }
}
