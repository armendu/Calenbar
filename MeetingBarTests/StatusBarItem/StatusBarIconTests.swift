//
//  StatusBarIconTests.swift
//  MeetingBarTests
//

import AppKit
import XCTest

@testable import Calenbar

@MainActor
final class StatusBarIconTests: BaseTestCase {
    private func presentation(
        mode: StatusBarTitleMode = .noUpcoming,
        title: String = "",
        icon: StatusBarIcon,
        layout: StatusBarTitleLayout = .none
    ) -> StatusBarPresentation {
        StatusBarPresentation(
            mode: mode,
            title: title,
            time: "",
            tooltip: nil,
            icon: icon,
            layout: layout,
            titleStyle: .normal,
            removeDeliveredNotifications: false
        )
    }

    /// Renders `presentation` into a fresh status item and returns the
    /// resulting button image; the status item is removed before returning.
    private func renderedImage(_ presentation: StatusBarPresentation) -> NSImage? {
        let controller = StatusBarItemController()
        defer { NSStatusBar.system.removeStatusItem(controller.statusItem) }
        controller.renderStatusBar(presentation)
        return controller.statusItem.button?.image
    }

    // MARK: - Shared images stay untouched

    func test_assetIconDoesNotResizeTheSharedNamedImage() throws {
        let name = "iconCalendar"
        let shared = try XCTUnwrap(NSImage(named: name))
        let originalSize = shared.size

        let image = renderedImage(presentation(icon: .asset(name)))

        XCTAssertEqual(shared.size, originalSize)
        XCTAssertEqual(image?.size, MenuStyleConstants.statusBarIconSize)
    }

    func test_placeholderServiceIconStaysHiddenNextToATitle() throws {
        let controller = StatusBarItemController()
        defer { NSStatusBar.system.removeStatusItem(controller.statusItem) }

        controller.renderStatusBar(presentation(
            mode: .nextEvent, title: "Standup", icon: .meetingService(nil), layout: .inline(showTime: false)
        ))

        XCTAssertEqual(try XCTUnwrap(controller.statusItem.button).imagePosition, .noImage)
    }

    // MARK: - Today's date icon

    func test_todaysDateIconIsASquareTemplateAtTheRequestedSize() {
        let icon = MenuStyleConstants.todaysDateIcon(pointSize: 20)

        XCTAssertEqual(icon.size, NSSize(width: 20, height: 20))
        XCTAssertTrue(icon.isTemplate, "template images tint with the menu bar's appearance")
    }

    func test_noUpcomingModeShowsTodaysDateIcon() {
        let image = renderedImage(presentation(icon: .todaysDate))

        let side = MenuStyleConstants.todaysDateIconSize
        XCTAssertEqual(image?.size, NSSize(width: side, height: side))
        XCTAssertTrue(image?.isTemplate ?? false)
    }

    // MARK: - Icon/title gap

    func test_trailingGapWidensTheIconOnly() {
        let image = NSImage(size: NSSize(width: 15, height: 15))

        let padded = MenuStyleConstants.iconWithTrailingGap(image, gap: 4)

        XCTAssertEqual(padded.size, NSSize(width: 19, height: 15))
    }

    func test_trailingGapKeepsTemplateRendering() {
        let image = NSImage(size: NSSize(width: 15, height: 15))
        image.isTemplate = true

        XCTAssertTrue(MenuStyleConstants.iconWithTrailingGap(image, gap: 4).isTemplate)
    }

    func test_iconIsGappedFromAVisibleTitle() {
        let image = renderedImage(presentation(
            mode: .nextEvent, title: "Standup", icon: .todaysDate, layout: .inline(showTime: false)
        ))

        let side = MenuStyleConstants.todaysDateIconSize
        XCTAssertEqual(image?.size, NSSize(width: side + MenuStyleConstants.statusBarIconTitleGap, height: side))
    }
}
