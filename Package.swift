// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MeetingBarLogic",
    platforms: [
        .macOS(.v26)
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
                "UI/StatusBar/StatusBarPresentation.swift",
                // CalenbarPanelViewModel.swift only defines pure, Foundation-only
                // shadow types (CalenbarEventInput, CalenbarTimeFormat,
                // CalenbarPanelStateInput, CalenbarPanelLabels) and the two
                // functions moved from MenuBuilder, operating on those shadow
                // types rather than the real MBEvent/StatusBarMenuState/TimeFormat.
                // The real-type adapters (`init(_ event: MBEvent)` etc.) live in
                // CalenbarPanelViewModel+MeetingBar.swift, which is app-target
                // only and deliberately NOT listed here — same split as
                // StatusBarPresentation.swift / StatusBarPresentation+MeetingBar.swift.
                "UI/StatusBar/CalenbarPanelViewModel.swift"
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
