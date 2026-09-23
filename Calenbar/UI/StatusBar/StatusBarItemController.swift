//
//  StatusBarItemController.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.06.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import KeyboardShortcuts

enum MenuStyleConstants {
    static let defaultFontSize: CGFloat = 13
    static let runningIconName = "running_icon"
    static let appIconName = "AppIcon"
    static let calendarCheckmarkIconName = "iconCalendarCheckmark"
    static let calendarIconName = "iconCalendar"
    static let iconSize: NSSize = .init(width: 16, height: 16)

    /// Loads a named asset; if the asset is missing or has been renamed,
    /// falls back to the bundle's runtime app icon and finally to a 1x1
    /// placeholder so the menu bar never crashes on a misconfigured Defaults
    /// value or a renamed asset.
    static func iconNamed(_ name: String) -> NSImage {
        if let image = NSImage(named: name) {
            return image
        }
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            return appIcon
        }
        return NSImage(size: NSSize(width: 1, height: 1))
    }

    /// The real Calendar.app icon, which macOS renders with today's actual
    /// date baked in — used wherever the app wants a "today" glyph (the
    /// status bar's no-upcoming-events icon, the glass panel's empty state)
    /// instead of a static checkmark/calendar asset.
    static var todaysCalendarIcon: NSImage {
        let candidatePaths = [
            "/System/Applications/Calendar.app",
            "/Applications/Calendar.app"
        ]
        for path in candidatePaths where FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
            ?? iconNamed(calendarIconName)
    }
}

struct StatusBarDependencies {
    var appState: @MainActor () -> AppState = { AppState() }
    var events: @MainActor () -> [MBEvent] = { [] }
    var send: @MainActor (AppAction) -> Void = { _ in }
    var openPreferences: @MainActor () -> Void = {}
    var quit: @MainActor () -> Void = {}
}

/// creates the menu in the system status bar, creates the menu items and controls the whole lifecycle.
@MainActor
final class StatusBarItemController {
    var statusItem: NSStatusItem!
    var statusItemMenu: NSMenu!
    let calenbarPanelController = CalenbarPanelController()

    /// Current event list, driven by the AppModel state.
    /// A non-nil `_eventsOverride` takes precedence (used by tests to inject
    /// events without wiring up the full app model chain).
    private var _eventsOverride: [MBEvent]?
    var events: [MBEvent] {
        get { _eventsOverride ?? dependencies.events() }
        set { _eventsOverride = newValue }
    }

    private var dependencies = StatusBarDependencies()

    private var cancellables = Set<AnyCancellable>()

    init() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        statusItemMenu = NSMenu(title: "MeetingBar in Status Bar Menu")

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusMenuBarAction)
        statusItem.button?.sendAction(on: [
            NSEvent.EventTypeMask.rightMouseDown, NSEvent.EventTypeMask.leftMouseUp,
            NSEvent.EventTypeMask.leftMouseDown
        ])

        // Temporary icon and menu before app delegate setup
        statusItem.button?.image = MenuStyleConstants.iconNamed(MenuStyleConstants.appIconName)
        statusItem.button?.image?.size = MenuStyleConstants.iconSize
        statusItem.button?.imagePosition = .imageLeft
        let menuItem = statusItemMenu.addItem(
            withTitle: "window_title_onboarding".loco(), action: nil, keyEquivalent: "")
        menuItem.isEnabled = false

        setupDefaultsObservers()
        setupKeyboardShortcuts()
    }

    private func setupDefaultsObservers() {
        // For all these keys, just redraw:
        Defaults.publisher(
            keys: .statusbarEventTitleLength, .eventTimeFormat,
            .eventTitleIconFormat, .showEventMaxTimeUntilEventThreshold,
            .showEventMaxTimeUntilEventEnabled, .showEventDetails,
            .shortenEventTitle, .menuEventTitleLength,
            .showEventEndTime, .showMeetingServiceIcon,
            .showEventCalendarColor,
            .timeFormat, .bookmarks,
            .personalEventsAppereance, .pastEventsAppereance,
            .declinedEventsAppereance, .ongoingEventVisibility,
            .showTimelineInMenu,
            options: []
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateTitle()
            self?.updateMenu()
        }
        .store(in: &cancellables)

        Defaults.publisher(.eventTitleFormat, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
                self?.updateTitle()
                self?.reconcileNotifications()
            }
            .store(in: &cancellables)

        Defaults.publisher(.preferredLanguage, options: [.initial])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                if I18N.instance.changeLanguage(to: change.newValue) {
                    self?.updateMenu()
                    self?.updateTitle()
                    self?.reconcileNotifications()
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(
            keys: .joinEventNotification,
            .joinEventNotificationTime,
            .endOfEventNotification,
            .endOfEventNotificationTime,
            .fullscreenNotification,
            .fullscreenNotificationTime,
            .fullscreenNotificationsForEventsWithoutMeetingLink,
            .automaticEventJoin,
            .automaticEventJoinTime,
            .runEventStartScript,
            .eventStartScriptTime,
            .eventStartScriptLocation,
            .dismissedEvents,
            options: []
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.reconcileNotifications()
        }
        .store(in: &cancellables)
    }

    private func reconcileNotifications() {
        dependencies.send(.reconcileNotifications)
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .createMeetingShortcut, action: createMeeting)

        KeyboardShortcuts.onKeyUp(for: .joinEventShortcut) {
            Task { @MainActor in self.joinNextMeeting() }
        }

        KeyboardShortcuts.onKeyUp(for: .openMenuShortcut) {
            Task { @MainActor in self.openMenu() }
        }

        KeyboardShortcuts.onKeyUp(for: .openClipboardShortcut, action: openLinkFromClipboard)

        KeyboardShortcuts.onKeyUp(for: .toggleMeetingTitleVisibilityShortcut) {
            Task { @MainActor in self.dependencies.send(.toggleMeetingTitleVisibility) }
        }
    }

    @objc
    func statusMenuBarAction(sender _: NSStatusItem) {
        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp {
            // Right button click — instant-join shortcut, unchanged by the
            // Calenbar glass panel below (this was never a menu trigger).
            joinNextMeeting()
        } else if event == nil || event?.type == .leftMouseUp {
            // Left click now shows the Liquid Glass panel instead of the
            // classic NSMenu directly. The classic menu (openMenu(), below)
            // is still reachable from the panel's "More…" row.
            //
            // Deliberately NOT handling .leftMouseDown here, even though
            // button.sendAction(on:) above still requests it: that was
            // needed for the old openMenu() → performClick() path (which
            // blocked inside NSMenu's own tracking loop, so a same-click
            // .leftMouseUp resend was effectively absorbed by the time it
            // arrived). CalenbarPanelController.toggle() is synchronous and
            // non-blocking, so acting on both .leftMouseDown and
            // .leftMouseUp would call showCalenbarPanel() twice per click —
            // open, then immediately close again before the panel is ever
            // visible. Only responding on mouse-up (a completed click, or
            // an accessibility/AppleScript-triggered click reporting no
            // event) avoids that.
            showCalenbarPanel()
        }
    }

    func openMenu() {
        statusItem.menu = statusItemMenu
        statusItem.button?.performClick(nil)  // ...and click
        statusItem.menu = nil
    }

    func showCalenbarPanel() {
        guard let button = statusItem.button else { return }
        calenbarPanelController.toggle(
            near: button,
            viewModel: currentCalenbarPanelViewModel(),
            onJoin: { [weak self] in self?.joinNextMeeting() },
            onSelectAgendaRow: { [weak self] row in self?.dependencies.send(.joinMeeting(eventID: row.id)) },
            onShowClassicMenu: { [weak self] in self?.openMenu() }
        )
    }

    /// Builds the panel's view model from the same `StatusBarMenuState` that
    /// drives `updateMenu()`'s classic `NSMenu`, so both surfaces always
    /// agree on what "next meeting"/"today's agenda" means.
    private func currentCalenbarPanelViewModel() -> CalenbarPanelViewModel {
        var appState = dependencies.appState()
        appState.events = events
        let menuState = StatusBarMenuState.make(from: appState)
        return CalenbarPanelViewModel.build(
            from: CalenbarPanelStateInput(menuState),
            now: Date(),
            isFantasticalInstalled: checkIsFantasticalInstalled(),
            locale: I18N.instance.locale,
            labels: .current
        )
    }

    func configure(dependencies: StatusBarDependencies) {
        self.dependencies = dependencies
    }

    func updateTitle() {
        // Keep the glass panel's countdown/agenda live while it's open —
        // this runs on the same refresh pipeline (Defaults changes + the
        // periodic CalendarSync timer) that already drives the status item
        // title, rather than a separate timer of its own.
        if calenbarPanelController.isVisible {
            calenbarPanelController.refresh(viewModel: currentCalenbarPanelViewModel())
        }

        let now = Date()
        let presentation = StatusBarPresenter.presentation(
            nextEvent: events.nextEvent().map(StatusBarEventPresentationInput.init),
            settings: .current,
            now: now,
            calendar: statusBarCalendar()
        )

        if presentation.removeDeliveredNotifications, Defaults[.joinEventNotification] {
            removeDeliveredNotifications()
        }

        renderStatusBar(presentation)
    }

    func renderStatusBar(_ presentation: StatusBarPresentation) {
        guard let button = statusItem.button else { return }

        button.image = nil
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = nil
        button.alignment = .center
        button.cell?.lineBreakMode = .byTruncatingTail

        switch presentation.icon {
        case .asset(let name):
            button.image = MenuStyleConstants.iconNamed(name)
            button.image?.size = MenuStyleConstants.iconSize
        case .meetingService(let service):
            button.image = getIconForMeetingService(service)
        case .todaysDate:
            button.image = MenuStyleConstants.todaysCalendarIcon
            button.image?.size = MenuStyleConstants.iconSize
        case .none:
            break
        }
        button.imagePosition = button.image?.name() == "no_online_session" ? .noImage : .imageLeft

        if presentation.mode == .nextEvent {
            button.attributedTitle = StatusBarTitleRenderer.attributedTitle(for: presentation)
            button.toolTip = presentation.tooltip
        }

        ensureStatusBarButtonIsVisible(button)
    }

    private func ensureStatusBarButtonIsVisible(_ button: NSStatusBarButton) {
        // A set-but-suppressed image (imagePosition == .noImage, e.g. the
        // "no_online_session" sentinel) is not visible, so treat it the same as a
        // missing image — otherwise the status item can render completely blank.
        guard button.image == nil || button.imagePosition == .noImage,
              button.title.isEmpty,
              button.attributedTitle.string.isEmpty
        else { return }

        button.image = MenuStyleConstants.iconNamed(MenuStyleConstants.appIconName)
        button.image?.size = MenuStyleConstants.iconSize
        button.imagePosition = .imageLeft
    }

    /*
     * -----------------------
     * MARK: - MENU SECTIONS
     * ------------------------
     */

    func updateMenu() {
        // Don't update the menu while it's open to avoid flickering
        if statusItem.menu != nil {
            return
        }

        var appState = dependencies.appState()
        appState.events = events
        let menuState = StatusBarMenuState.make(from: appState)
        let builder = MenuBuilder(target: self, state: menuState)

        statusItemMenu.autoenablesItems = false
        statusItemMenu.removeAllItems()

        statusItemMenu.items += builder.buildTopSection()

        if menuState.hasSelectedCalendars {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

            switch menuState.events.showEventsForPeriod {
            case .today:
                statusItemMenu.items += builder.buildDateSection(
                    date: today, title: "status_bar_section_today".loco(),
                    events: menuState.todayEvents,
                    subdueEmptyState: menuState.todayEvents.isEmpty
                        && !menuState.tomorrowEvents.isEmpty
                )
            case .today_n_tomorrow:
                statusItemMenu.items += builder.buildDateSection(
                    date: today, title: "status_bar_section_today".loco(),
                    events: menuState.todayEvents)

                statusItemMenu.addItem(NSMenuItem.separator())

                statusItemMenu.items += builder.buildDateSection(
                    date: tomorrow, title: "status_bar_section_tomorrow".loco(),
                    events: menuState.tomorrowEvents)
            }
        }
        statusItemMenu.addItem(NSMenuItem.separator())
        statusItemMenu.items += builder.buildJoinSection(
            nextEvent: menuState.nextEvent,
            includeJoinAction: false
        )

        if !menuState.meetings.bookmarks.isEmpty {
            statusItemMenu.addItem(NSMenuItem.separator())
            statusItemMenu.items += builder.buildBookmarksSection(bookmarks: menuState.meetings.bookmarks)
        }
        statusItemMenu.addItem(NSMenuItem.separator())

        statusItemMenu.items += builder.buildPreferencesSection()
    }

    /*
     * -----------------------
     * MARK: - Actions
     * ------------------------
     */

    @objc func createMeetingAction() {
        createMeeting()
    }

    @objc
    func joinNextMeeting() {
        if let nextEvent = events.nextEvent() {
            dependencies.send(.joinMeeting(eventID: nextEvent.id))
        } else {
            AppMessageCenter.shared.post(.nextMeetingMissing)
        }
    }

    @objc
    func joinEvent(sender: NSMenuItem) {
        guard let event = sender.representedObject as? MBEvent else {
            AppMessageCenter.shared.post(.nextMeetingMissing)
            return
        }
        dependencies.send(.joinMeeting(eventID: event.id))
    }

    @objc
    func dismissNextMeetingAction() {
        if let nextEvent = events.nextEvent() {
            dependencies.send(.dismissMeeting(eventID: nextEvent.id))
            AppMessageCenter.shared.post(.meetingDismissed(title: nextEvent.title))

            updateTitle()
            updateMenu()
            reconcileNotifications()
        }
    }

    @objc
    func undismissMeetingsActions() {
        dependencies.send(.clearDismissedMeetings)
        AppMessageCenter.shared.post(.allDismissalsRemoved)

        updateTitle()
        updateMenu()
        reconcileNotifications()
    }

    @objc
    func openLinkFromClipboardAction() {
        openLinkFromClipboard()
    }

    @objc
    func toggleMeetingTitleVisibility() {
        dependencies.send(.toggleMeetingTitleVisibility)
    }

    @objc
    func joinBookmark(sender: NSMenuItem) {
        if let bookmark: Bookmark = sender.representedObject as? Bookmark {
            MeetingOpener.open(
                meetingLink: MeetingLink(service: MeetingServices(rawValue: bookmark.service), url: bookmark.url))
        }
    }

    @objc
    func clickOnEvent(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            dependencies.send(.joinMeeting(eventID: event.id))
        }
    }

    @objc
    func joinMeetingLinkCandidate(sender: NSMenuItem) {
        if let candidate = sender.representedObject as? MeetingLinkCandidate {
            MeetingOpener.open(
                meetingLink: MeetingLink(service: candidate.service, url: candidate.url))
        }
    }

    @objc
    func openEventInCalendar(sender: NSMenuItem) {
        // The menu attaches the provider-specific calendar URL directly
        // (ical://ekevent/… for EventKit, htmlLink for Google).
        if let url = sender.representedObject as? URL {
            url.openInDefaultBrowser()
        }
    }

    @objc func handleManualRefresh() {
        dependencies.send(.refreshCalendars)
    }

    @objc func reconnectProviderAction() {
        dependencies.send(.changeProvider(stateProvider, signOut: true))
    }

    @objc func openCalendarPermissionsAction() {
        NSWorkspace.shared.open(Links.calendarPreferences)
    }

    @objc
    func dismissEvent(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            dismiss(event: event)
        }
    }

    func dismiss(event: MBEvent) {
        dependencies.send(.dismissMeeting(eventID: event.id))

        updateTitle()
        updateMenu()
        reconcileNotifications()
    }

    @objc
    func undismissEvent(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            dependencies.send(.undismissMeeting(eventID: event.id))

            updateTitle()
            updateMenu()
            reconcileNotifications()
        }
    }

    @objc
    func copyEventMeetingLink(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            if let meetingLink = event.meetingLink {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(meetingLink.url.absoluteString, forType: .string)
            } else {
                AppMessageCenter.shared.post(.meetingLinkMissing(title: event.title))
            }
        }
    }

    @objc
    func emailAttendees(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            MeetingOpener.emailAttendees(for: event)
        }
    }

    @objc
    func openEventInFantastical(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            openInFantastical(startDate: event.startDate, title: event.title)
        }
    }

    @objc
    func openPreferencesAction() {
        dependencies.openPreferences()
    }

    private var stateProvider: EventStoreProvider {
        dependencies.appState().activeProvider
    }

    @objc
    func quitAction() {
        dependencies.quit()
    }
}

@MainActor
enum StatusBarTitleRenderer {
    static func attributedTitle(for presentation: StatusBarPresentation) -> NSAttributedString {
        switch presentation.layout {
        case .none:
            return NSAttributedString(string: "")
        case .inline(let showTime):
            var eventTitle = presentation.title
            if showTime {
                eventTitle += " " + presentation.time
            }
            return NSAttributedString(
                string: eventTitle,
                attributes: titleAttributes(
                    style: presentation.titleStyle,
                    font: NSFont.systemFont(ofSize: MenuStyleConstants.defaultFontSize)
                )
            )
        case .stacked:
            return stackedTitle(for: presentation)
        }
    }

    private static func stackedTitle(for presentation: StatusBarPresentation) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: presentation.title,
            attributes: titleAttributes(
                style: presentation.titleStyle,
                font: NSFont.systemFont(ofSize: 12),
                baselineOffset: -3
            )
        )
        title.append(
            NSAttributedString(
                string: "\n" + presentation.time,
                attributes: [
                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9),
                    NSAttributedString.Key.foregroundColor: NSColor.lightGray
                ]
            ))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.7
        paragraphStyle.alignment = .center
        title.addAttributes(
            [NSAttributedString.Key.paragraphStyle: paragraphStyle],
            range: NSRange(location: 0, length: title.length)
        )
        return title
    }

    /// NSStatusBarButton's `imagePosition = .imageLeft` butts the title
    /// directly against the icon with no configurable gap, reading as
    /// cramped. A small head indent on the title's paragraph style nudges
    /// the text away from the icon without affecting the icon itself.
    private static let iconTitleGap: CGFloat = 4

    private static func titleAttributes(
        style: StatusBarTitleStyle,
        font: NSFont,
        baselineOffset: CGFloat? = nil
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = iconTitleGap
        paragraphStyle.headIndent = iconTitleGap
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        if let baselineOffset {
            attributes[.baselineOffset] = baselineOffset
        }
        switch style {
        case .normal:
            break
        case .inactive:
            attributes[.foregroundColor] = NSColor.disabledControlTextColor
        case .underlined:
            attributes[.underlineStyle] =
                NSUnderlineStyle.single.rawValue
                | NSUnderlineStyle.patternDot.rawValue
                | NSUnderlineStyle.byWord.rawValue
        }
        return attributes
    }
}

private func statusBarCalendar() -> Calendar {
    var calendar = Calendar.current
    calendar.locale = I18N.instance.locale
    return calendar
}

enum NextEventState {
    case none
    case afterThreshold(MBEvent)
    case nextEvent(MBEvent)
}
