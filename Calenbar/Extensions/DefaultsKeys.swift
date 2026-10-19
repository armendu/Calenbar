//
//  DefaultsKeys.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.06.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//
@preconcurrency import Defaults
import Foundation

extension Defaults.Keys {
    // General
    static let appVersion = Key<String>("appVersion", default: "2.0.5", suite: .calenbar)
    static let lastRevisedVersionInChangelog = Key<String>(
        "lastRevisedVersionInChangelog", default: "4.2.0", suite: .calenbar)

    static let selectedCalendarIDs = Key<[String]>("selectedCalendarIDs", default: [], suite: .calenbar)
    static let selectedCalendarIDsByProvider = Key<[String: [String]]>(
        "selectedCalendarIDsByProvider",
        default: [:],
        suite: .calenbar
    )
    static let selectedCalendarIDsByProviderMigrated = Key<Bool>(
        "selectedCalendarIDsByProviderMigrated",
        default: false,
        suite: .calenbar
    )
    static let eventStoreProvider = Key<EventStoreProvider>(
        "eventStoreProvider", default: .macOSEventKit, suite: .calenbar)

    static let onboardingCompleted = Key<Bool>("onboardingCompleted", default: false, suite: .calenbar)

    static let showEventsForPeriod = Key<ShowEventsForPeriod>(
        "showEventsForPeriod", default: .today, suite: .calenbar)
    static let joinEventNotification = Key<Bool>("joinEventNotification", default: true, suite: .calenbar)
    static let joinEventNotificationTime = Key<TimeBeforeEvent>(
        "joinEventNotificationTime", default: .atStart, suite: .calenbar)

    static let endOfEventNotification = Key<Bool>("endOfEventNotification", default: true, suite: .calenbar)
    static let endOfEventNotificationTime = Key<TimeBeforeEventEnd>(
        "endOfEventNotificationTime", default: .atEnd, suite: .calenbar)

    static let fullscreenNotification = Key<Bool>("fullscreenNotification", default: false, suite: .calenbar)
    static let fullscreenNotificationTime = Key<TimeBeforeEvent>(
        "fullscreenNotificationTime", default: .atStart, suite: .calenbar)
    static let fullscreenNotificationsForEventsWithoutMeetingLink = Key<Bool>(
        "fullscreenNotificationsForEventsWithoutMeetingLink",
        default: false,
        suite: .calenbar
    )
    static let processedEventsForFullscreenNotification = Key<[ProcessedEvent]>(
        "processedEventsForFullscreenNotification", default: [], suite: .calenbar)

    static let preferredLanguage = Key<AppLanguage>("preferredLanguage", default: .system, suite: .calenbar)

    // Status Bar Appearance
    static let eventTitleFormat = Key<EventTitleFormat>("eventTitleFormat", default: .show, suite: .calenbar)
    static let eventTimeFormat = Key<EventTimeFormat>("eventTimeFormat", default: .show, suite: .calenbar)

    static let eventTitleIconFormat = Key<EventTitleIconFormat>(
        "eventTitleIconFormat", default: .calendar, suite: .calenbar)
    static let panelIconColor = Key<PanelIconColor>("panelIconColor", default: .monochrome, suite: .calenbar)
    static let statusbarEventTitleLength = Key<Int>(
        "statusbarEventTitleLength", default: statusbarEventTitleLengthLimits.max, suite: .calenbar)

    static let hideMeetingTitle = Key<Bool>("hideMeetingTitle", default: false, suite: .calenbar)
    static let dismissedEvents = Key<[ProcessedEvent]>("dismissedEvents", default: [], suite: .calenbar)

    static let ongoingEventVisibility = Key<OngoingEventVisibility>(
        "ongoingEventVisibility", default: .showTenMinBeforeNext, suite: .calenbar)

    // Menu Appearance
    static let showTimelineInMenu = Key<Bool>("showTimelineInMenu", default: true, suite: .calenbar)
    // if the event title in the menu should be shortened or not -> the length will be stored in field menuEventTitleLength
    static let shortenEventTitle = Key<Bool>("shortenEventTitle", default: true, suite: .calenbar)
    static let menuEventTitleLength = Key<Int>("menuEventTitleLength", default: 30, suite: .calenbar)

    static let showEventDetails = Key<Bool>("showEventDetails", default: false, suite: .calenbar)
    static let showMeetingServiceIcon = Key<Bool>("showMeetingServiceIcon", default: true, suite: .calenbar)
    static let showEventCalendarColor = Key<Bool>("showEventCalendarColor", default: true, suite: .calenbar)

    static let declinedEventsAppereance = Key<DeclinedEventsAppereance>(
        "declinedEventsAppereance", default: .strikethrough, suite: .calenbar)
    static let pastEventsAppereance = Key<PastEventsAppereance>(
        "pastEventsAppereance", default: .show_inactive, suite: .calenbar)
    static let personalEventsAppereance = Key<PastEventsAppereance>(
        "personalEventsAppereance", default: .show_active, suite: .calenbar)

    static let showEventMaxTimeUntilEventThreshold = Key<Int>(
        "showEventMaxTimeUntilEventThreshold", default: 60, suite: .calenbar)
    static let showEventMaxTimeUntilEventEnabled = Key<Bool>(
        "showEventMaxTimeUntilEventEnabled", default: true, suite: .calenbar)

    // appearance of pending events should be shown in the statusbar and menu
    static let showPendingEvents = Key<PendingEventsAppereance>(
        "showPendingEvents", default: PendingEventsAppereance.show, suite: .calenbar)

    // appearance of tentative events
    static let showTentativeEvents = Key<TentativeEventsAppereance>(
        "showTentativeEvents", default: TentativeEventsAppereance.show, suite: .calenbar)

    static let timeFormat = Key<TimeFormat>("timeFormat", default: .military, suite: .calenbar)

    // Bookmarks
    static let bookmarks = Key<[Bookmark]>("bookmarks", default: [], suite: .calenbar)

    // all browser configurations
    static let browsers = Key<[Browser]>("browsers", default: [], suite: .calenbar)

    // default browser for meeting links
    static let defaultBrowser = Key<Browser>(
        "defaultBrowser",
        default: Browser(name: "Default Browser", path: "", arguments: "", deletable: false), suite: .calenbar)

    // show all day events - by default true
    static let allDayEvents = Key<AlldayEventsAppereance>(
        "allDayEvents", default: AlldayEventsAppereance.show, suite: .calenbar)

    // show all day events - by default show all, also events without any link
    static let nonAllDayEvents = Key<NonAlldayEventsAppereance>(
        "nonAllDayEvents", default: NonAlldayEventsAppereance.show, suite: .calenbar)

    // show the end time of a meeting in the meetingbar for each event entry
    static let showEventEndTime = Key<Bool>("showEventEndTime", default: true, suite: .calenbar)

    // Integrations
    static let createMeetingService = Key<CreateMeetingServices>(
        "createMeetingService", default: .zoom, suite: .calenbar)

    // custom url to create meetings
    static let createMeetingServiceUrl = Key<String>("createMeetingServiceUrl", default: "", suite: .calenbar)

    static let meetBrowser = Key<Browser>("meetBrowser", default: systemDefaultBrowser, suite: .calenbar)
    static let zoomBrowser = Key<Browser>("zoomBrowser", default: systemDefaultBrowser, suite: .calenbar)
    static let teamsBrowser = Key<Browser>("teamsBrowser", default: systemDefaultBrowser, suite: .calenbar)
    static let jitsiBrowser = Key<Browser>("jitsiBrowser", default: systemDefaultBrowser, suite: .calenbar)
    static let slackBrowser = Key<Browser>("slackBrowser", default: systemDefaultBrowser, suite: .calenbar)
    static let riversideBrowser = Key<Browser>("riversideBrowser", default: systemDefaultBrowser, suite: .calenbar)

    /// Unified per-provider browser preferences.
    /// Keyed by MeetingProvider.id (= MeetingServices.rawValue for built-in providers).
    /// Replaces the individual meetBrowser/zoomBrowser/… keys. See MeetingOpenPreferencesMigration.
    static let providerBrowsers = Key<[String: Browser]>("providerBrowsers", default: [:], suite: .calenbar)

    /// Opt-in provider-specific app/web/PWA mode IDs.
    /// Unknown values are ignored and fall back to normal browser resolution.
    static let providerOpeningModes = Key<[String: String]>("providerOpeningModes", default: [:], suite: .calenbar)

    /**
     * browser used for creating a new meeting
     */
    static let browserForCreateMeeting = Key<Browser>(
        "browserForCreateMeeting", default: systemDefaultBrowser, suite: .calenbar)

    // Advanced
    static let automaticEventJoin = Key<Bool>("automaticEventJoin", default: false, suite: .calenbar)
    static let automaticEventJoinTime = Key<TimeBeforeEvent>(
        "automaticEventJoinTime", default: .atStart, suite: .calenbar)
    static let processedEventsForAutoJoin = Key<[ProcessedEvent]>(
        "processedEventsForAutoJoin", default: [], suite: .calenbar)

    static let joinEventScriptLocation = Key<URL?>("joinEventScriptLocation", default: nil, suite: .calenbar)
    static let runJoinEventScript = Key<Bool>("runAppleScriptWhenJoiningEvent", default: false, suite: .calenbar)
    static let joinEventScript = Key<String>(
        "joinEventScript", default: "preferences_advanced_apple_script_placeholder".loco(), suite: .calenbar)

    static let eventStartScriptLocation = Key<URL?>("eventStartScriptLocation", default: nil, suite: .calenbar)
    static let runEventStartScript = Key<Bool>("runEventStartScript", default: false, suite: .calenbar)
    static let eventStartScriptTime = Key<TimeBeforeEvent>(
        "eventStartScriptTime", default: .atStart, suite: .calenbar)
    static let eventStartScript = Key<String>(
        "eventStartScript", default: eventStartScriptPlaceholder, suite: .calenbar)
    static let processedEventsForRunScriptOnEventStart = Key<[ProcessedEvent]>(
        "processedEventsForRunScriptOnEventStart", default: [], suite: .calenbar)

    static let customRegexes = Key<[String]>("customRegexes", default: [], suite: .calenbar)
    static let filterEventRegexes = Key<[String]>("filterEventRegexes", default: [], suite: .calenbar)
}
