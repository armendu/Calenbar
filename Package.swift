// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MeetingBarLogic",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "MeetingBarLogic", targets: ["MeetingBarLogic"])
    ],
    targets: [
        .target(
            name: "MeetingBarLogic",
            path: "MeetingBar",
            exclude: [
                // Exclude app-layer files that depend on AppKit/Defaults/EventKit.
                // SPM scans the whole MeetingBar/ tree for resources; these paths
                // prevent it from picking up .lproj bundles and asset catalogues.
                "Resources ",
                "Assets.xcassets",
                "Base.lproj",
                "Preview Content"
            ],
            sources: [
                // Utilities/Diagnostics
                "Utilities/Diagnostics/DiagnosticsReport.swift",
                // Notifications
                "Notifications/EventActionPolicy.swift",
                "Notifications/NotificationPlanner.swift",
                // Calendar
                "Calendar/EventFiltering.swift",
                "Calendar/EventSelection.swift",
                "Calendar/Providers/Google/GoogleCalendarPolicy.swift",
                // Meetings
                "Meetings/MeetingLinkDetector.swift",
                "Meetings/MeetingProvider.swift",
                // UI/StatusBar
                "UI/StatusBar/StatusBarPresentation.swift"
                // NOTE: "UI/StatusBar/CalenbarPanelViewModel.swift" is deliberately
                // NOT listed here yet, even though it only imports Foundation.
                // Its `meetingSummaryPresentation`/`eventTimePresentation`/
                // `CalenbarPanelViewModel.build` API takes the real `MBEvent`
                // and `StatusBarMenuState` as parameters (per the plan), and
                // those types are not part of this isolated target:
                //   - MBEvent.calendar is MBCalendar, which stores an NSColor
                //     (Calendar/MBCalendar.swift, not listed above).
                //   - StatusBarMenuState.settings is AppSettings
                //     (Settings/AppSettings.swift), which imports the external
                //     `Defaults` package — not currently a dependency of this
                //     target, and adding it plus AppSettings' ~15 supporting
                //     enums (Utilities/Constants.swift) is a much larger,
                //     separate change than this file's own logic.
                // Adding this file's path here as-is would break `swift build`
                // for the whole package. Until MBEvent/StatusBarMenuState (or a
                // pure equivalent) are deliberately brought into this target,
                // CalenbarPanelViewModel.swift is a normal app-target-only file:
                // MenuBuilder.swift calls its two moved free functions, and it
                // is exercised by CalenbarPanelViewModelTests.swift only once
                // that follow-up work happens.
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "MeetingBarLogicTests",
            dependencies: ["MeetingBarLogic"],
            path: "MeetingBarLogicTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        )
    ]
)
