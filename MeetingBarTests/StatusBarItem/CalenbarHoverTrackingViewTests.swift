//
//  CalenbarHoverTrackingViewTests.swift
//  MeetingBarTests
//

import AppKit
import XCTest

@testable import Calenbar

@MainActor
final class CalenbarHoverTrackingViewTests: XCTestCase {
    private var hoverChanges: [Bool] = []

    private func makeView(pointingHand: Bool = true) -> CalenbarHoverTrackingView {
        let view = CalenbarHoverTrackingView()
        view.showsPointingHand = pointingHand
        view.onChange = { [unowned self] in self.hoverChanges.append($0) }
        return view
    }

    private func event(_ type: NSEvent.EventType) throws -> NSEvent {
        try XCTUnwrap(NSEvent.enterExitEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
        ))
    }

    func test_reportsEnterAndExit() throws {
        let view = makeView()

        view.mouseEntered(with: try event(.mouseEntered))
        view.mouseExited(with: try event(.mouseExited))

        XCTAssertEqual(hoverChanges, [true, false])
    }

    func test_letsClicksThroughToTheRowUnderneath() {
        XCTAssertNil(makeView().hitTest(.zero))
    }

    func test_showsPointingHandOnlyWhileHovered() throws {
        let view = makeView()

        view.mouseEntered(with: try event(.mouseEntered))
        XCTAssertTrue(view.isShowingPointingHand)

        view.mouseExited(with: try event(.mouseExited))
        XCTAssertFalse(view.isShowingPointingHand)
    }

    func test_rowsWithoutAnActionKeepTheArrowCursor() throws {
        let view = makeView(pointingHand: false)

        view.mouseEntered(with: try event(.mouseEntered))

        XCTAssertFalse(view.isShowingPointingHand)
        XCTAssertEqual(hoverChanges, [true])
    }

    /// Closing the panel while hovering never delivers `mouseExited`, so
    /// leaving the window has to release the cursor and the hover state.
    func test_leavingTheWindowWhileHoveredReleasesCursorAndHover() throws {
        let view = makeView()
        view.mouseEntered(with: try event(.mouseEntered))

        view.viewWillMove(toWindow: nil)

        XCTAssertFalse(view.isShowingPointingHand)
        XCTAssertEqual(hoverChanges, [true, false])
    }

    func test_leavingTheWindowWithoutHoverChangesNothing() {
        let view = makeView()

        view.viewWillMove(toWindow: nil)

        XCTAssertEqual(hoverChanges, [])
    }
}
