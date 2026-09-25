//
//  StatusBarIconPolicyTests.swift
//  MeetingBarLogicTests
//

import XCTest

@testable import MeetingBarLogic

final class StatusBarIconPolicyTests: XCTestCase {
    private let assets = StatusBarIconAssets(appIcon: "AppIcon")

    private func icon(
        mode: StatusBarTitleMode,
        format: StatusBarIconFormat,
        formatAssetName: String? = nil,
        meetingService: MeetingServices? = nil
    ) -> StatusBarIcon {
        StatusBarIconPolicy.icon(
            mode: mode,
            format: format,
            formatAssetName: formatAssetName ?? rawAssetName(for: format),
            meetingService: meetingService,
            assets: assets
        )
    }

    private func rawAssetName(for format: StatusBarIconFormat) -> String {
        switch format {
        case .calendar: return "iconCalendar"
        case .appicon: return "AppIcon"
        case .eventtype: return "ms_teams_icon"
        case .none: return "no_online_session"
        }
    }

    // MARK: - idle

    func testIdleAlwaysReturnsAppIcon() {
        let formats: [StatusBarIconFormat] = [.calendar, .appicon, .eventtype, .none]
        for format in formats {
            XCTAssertEqual(
                icon(mode: .idle, format: format),
                .asset(assets.appIcon),
                "format \(format) under .idle should still produce app icon"
            )
        }
    }

    // MARK: - noUpcoming

    func testNoUpcomingAppIconFormatReturnsAppIcon() {
        XCTAssertEqual(icon(mode: .noUpcoming, format: .appicon), .asset(assets.appIcon))
    }

    func testNoUpcomingNonAppIconFormatsReturnTodaysDate() {
        XCTAssertEqual(icon(mode: .noUpcoming, format: .calendar), .todaysDate)
        XCTAssertEqual(icon(mode: .noUpcoming, format: .eventtype), .todaysDate)
        XCTAssertEqual(icon(mode: .noUpcoming, format: .none), .todaysDate)
    }

    // MARK: - afterThreshold

    func testAfterThresholdAppIconFormatReturnsAppIcon() {
        XCTAssertEqual(icon(mode: .afterThreshold, format: .appicon), .asset(assets.appIcon))
    }

    func testAfterThresholdNonAppIconFormatsReturnTodaysDate() {
        XCTAssertEqual(icon(mode: .afterThreshold, format: .calendar), .todaysDate)
        XCTAssertEqual(icon(mode: .afterThreshold, format: .eventtype), .todaysDate)
        XCTAssertEqual(icon(mode: .afterThreshold, format: .none), .todaysDate)
    }

    // MARK: - nextEvent

    func testNextEventNoneFormatReturnsNoIcon() {
        XCTAssertEqual(icon(mode: .nextEvent, format: .none), .none)
    }

    func testNextEventEventTypeReturnsMeetingService() {
        XCTAssertEqual(
            icon(mode: .nextEvent, format: .eventtype, meetingService: .zoom),
            .meetingService(.zoom)
        )
    }

    func testNextEventEventTypeWithoutMeetingServicePassesNil() {
        XCTAssertEqual(
            icon(mode: .nextEvent, format: .eventtype, meetingService: nil),
            .meetingService(nil)
        )
    }

    func testNextEventAppIconFormatReturnsAppIconAsset() {
        XCTAssertEqual(
            icon(mode: .nextEvent, format: .appicon),
            .asset("AppIcon")
        )
    }

    /// The calendar format shows today's date, the same icon as when nothing
    /// is coming up, so the status item doesn't switch glyphs.
    func testNextEventCalendarFormatReturnsTodaysDate() {
        XCTAssertEqual(icon(mode: .nextEvent, format: .calendar), .todaysDate)
    }

    // MARK: - boundary cases

    func testFormatAssetNameOverridesAssetsForAppIconFormat() {
        // .appicon passes the format's asset name through, so behavior follows
        // the asset pinned to the Defaults enum, not the StatusBarIconAssets table.
        let custom = icon(
            mode: .nextEvent,
            format: .appicon,
            formatAssetName: "future_app_icon"
        )
        XCTAssertEqual(custom, .asset("future_app_icon"))
    }
}
