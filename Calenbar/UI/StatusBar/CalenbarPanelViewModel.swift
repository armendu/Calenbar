//
//  CalenbarPanelViewModel.swift
//  MeetingBar
//

import Foundation

// MARK: - Meeting summary presentation

/// Moved here from `MeetingSummaryView.swift` so it can be produced by pure,
/// AppKit-free logic (`meetingSummaryPresentation(for:...)` below) instead of
/// living only inside the SwiftUI/AppKit view file. `MeetingSummaryView`
/// still renders it — no extra import is needed there since both files
/// compile into the same app target/module.
struct MeetingSummaryPresentation: Equatable {
    let sectionTitle: String
    let eventTitle: String
    let metadata: [String]
    let meetingService: MeetingServices?
    /// Relative time until the meeting starts (e.g. "in 25m"); nil for
    /// running meetings, where the section title already says enough.
    var countdown: String?

    var metadataText: String {
        metadata.joined(separator: " • ")
    }

    var sectionTitleText: String {
        guard let countdown, !countdown.isEmpty else { return sectionTitle }
        return "\(sectionTitle) • \(countdown)"
    }
}

/// Formatted start/end time strings for one event, plus the `DateFormatter`
/// used to produce them (reused by submenu detail rows that need additional
/// formatting, e.g. `MenuBuilder.addEventDuration`).
///
/// Moved here from `MenuBuilder` (was a private type nested inside it) so it
/// can be shared by both `MenuBuilder` and `CalenbarPanelViewModel`.
struct EventTimePresentation {
    let formatter: DateFormatter
    let start: String
    let end: String
}

// MARK: - Shadow inputs

// `meetingSummaryPresentation`/`eventTimePresentation`/`CalenbarPanelViewModel.build`
// need to compile inside the hostless `MeetingBarLogic` SPM target, so they
// can't take the real `MBEvent`/`StatusBarMenuState`/`TimeFormat` directly:
//   - MBEvent.calendar is MBCalendar, which stores an NSColor.
//   - StatusBarMenuState.settings is AppSettings, which imports the external
//     `Defaults` package (not a dependency of this target), and TimeFormat
//     itself is `Defaults.Serializable`.
//   - Localized strings normally come from `"...".loco()` / `I18N`, but no
//     other pure file in this target calls those either (confirmed: none of
//     the current `MeetingBarLogic` sources reference `.loco()` or `I18N`) —
//     the established convention is to take already-localized strings in as
//     data (see `StatusBarTitleLabels` in StatusBarPresentation.swift), not
//     to look them up from policy code.
//
// So, mirroring `StatusBarEventPresentationInput`/`StatusBarTitleLabels` in
// StatusBarPresentation.swift (and how `MeetingServices` itself was
// relocated into MeetingLinkDetector.swift for the same reason), these are
// pure, AppKit/Defaults/I18N-free mirrors of just the fields the moved
// functions read. `CalenbarPanelViewModel+MeetingBar.swift` (app-target
// only) adapts the real types into these.

/// Pure mirror of the `MBEvent` fields `meetingSummaryPresentation`,
/// `eventTimePresentation`, and `CalenbarPanelViewModel.build` read.
struct CalenbarEventInput: Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let meetingService: MeetingServices?
    let calendarEmail: String?
    let calendarSource: String
    let calendarTitle: String
    let organizerEmail: String?
}

/// Pure mirror of `TimeFormat` (Utilities/Constants.swift), which is
/// `Defaults.Serializable` and therefore not visible inside this target.
enum CalenbarTimeFormat: Equatable {
    case twelveHour
    case twentyFourHour
}

/// Pure mirror of the `StatusBarMenuState` fields `CalenbarPanelViewModel.build`
/// reads.
struct CalenbarPanelStateInput: Equatable {
    let nextEvent: CalenbarEventInput?
    let todayEvents: [CalenbarEventInput]
    let timeFormat: CalenbarTimeFormat
}

/// Pre-localized strings the pure panel logic needs, in place of calling
/// `.loco()` directly. Mirrors `StatusBarTitleLabels`; populated by
/// `CalenbarPanelLabels.current` in the `+MeetingBar.swift` adapter.
struct CalenbarPanelLabels: Equatable {
    let noTitle: String
    let currentMeetingSectionTitle: String
    let nextMeetingSectionTitle: String
    /// Format string with one `%@` placeholder for the relative countdown,
    /// e.g. "in %@" — the raw (unsubstituted) localized value of
    /// `status_bar_event_status_in`.
    let countdownFormat: String
    let allDayStartLabel: String
    let noUpcomingMessage: String
}

// MARK: - Calenbar panel view model

/// One row of the "today" agenda list in the glass panel.
struct CalenbarAgendaRow: Equatable, Identifiable {
    let id: String
    let title: String
    let timeRangeText: String
    let meetingService: MeetingServices?
    let isCurrent: Bool
}

/// AppKit-free snapshot of everything the glass panel's primary section
/// needs to render: the current/next meeting summary card, plus today's
/// agenda rows. Built from the same data that drives the existing
/// `MenuBuilder`-based dropdown (via `CalenbarPanelStateInput`, adapted from
/// `StatusBarMenuState`), so both stay in sync.
struct CalenbarPanelViewModel: Equatable {
    var summary: MeetingSummaryPresentation?
    var agenda: [CalenbarAgendaRow]
    var emptyStateMessage: String?

    static func build(
        from state: CalenbarPanelStateInput,
        now: Date,
        isFantasticalInstalled: Bool,
        locale: Locale,
        labels: CalenbarPanelLabels
    ) -> CalenbarPanelViewModel {
        guard let next = state.nextEvent else {
            return CalenbarPanelViewModel(
                summary: nil,
                agenda: [],
                emptyStateMessage: labels.noUpcomingMessage
            )
        }

        let summary = meetingSummaryPresentation(
            for: next,
            timeFormat: state.timeFormat,
            locale: locale,
            now: now,
            isFantasticalInstalled: isFantasticalInstalled,
            labels: labels
        )

        let agenda = state.todayEvents.map { event -> CalenbarAgendaRow in
            let time = eventTimePresentation(
                for: event,
                timeFormat: state.timeFormat,
                locale: locale,
                allDayLabel: labels.allDayStartLabel
            )
            let isCurrent = event.startDate <= now && event.endDate > now
            return CalenbarAgendaRow(
                id: event.id,
                title: event.title.isEmpty ? labels.noTitle : event.title,
                timeRangeText: event.isAllDay ? time.start : "\(time.start) – \(time.end)",
                meetingService: event.meetingService,
                isCurrent: isCurrent
            )
        }

        return CalenbarPanelViewModel(summary: summary, agenda: agenda, emptyStateMessage: nil)
    }
}

// MARK: - Moved from MenuBuilder

/// Moved from `MenuBuilder` (was `meetingSummaryPresentation(for:)`, an
/// instance method reading `self.now`) so this logic is reusable outside
/// menu construction — by `CalenbarPanelViewModel.build` above, and by
/// `MenuBuilder.makeMeetingSummaryItem`, which now calls this free function
/// (via the `CalenbarEventInput(event)` adapter) instead of its own
/// (removed) method.
///
/// `isFantasticalInstalled` is threaded through for signature parity with
/// `CalenbarPanelViewModel.build` (which needs it for other panel sections);
/// the summary card itself does not use it, matching the original method's
/// behavior exactly.
func meetingSummaryPresentation(
    for event: CalenbarEventInput,
    timeFormat: CalenbarTimeFormat,
    locale: Locale,
    now: Date,
    isFantasticalInstalled: Bool,
    labels: CalenbarPanelLabels
) -> MeetingSummaryPresentation {
    let isCurrent = event.startDate <= now && event.endDate > now
    let eventTitle = event.title.isEmpty ? labels.noTitle : event.title
    let time = eventTimePresentation(
        for: event,
        timeFormat: timeFormat,
        locale: locale,
        allDayLabel: labels.allDayStartLabel
    )
    let timeRange = event.isAllDay
        ? time.start
        : "\(time.start) – \(time.end)"
    let meetingProvider = event.meetingService
        .flatMap(MeetingProvider.provider(for:))?
        .displayName
    let account = firstMeaningfulMetadataValue([
        event.calendarEmail,
        event.calendarSource == "unknown" ? nil : event.calendarSource,
        event.organizerEmail
    ])

    let countdown: String?
    if isCurrent || event.isAllDay {
        countdown = nil
    } else {
        let timeLeft = StatusBarTitlePolicy.formattedTimeLeft(
            from: now,
            to: event.startDate,
            calendar: Calendar.current
        )
        countdown = timeLeft.isEmpty ? nil : String(format: labels.countdownFormat, timeLeft)
    }

    return MeetingSummaryPresentation(
        sectionTitle: isCurrent
            ? labels.currentMeetingSectionTitle
            : labels.nextMeetingSectionTitle,
        eventTitle: eventTitle,
        metadata: uniqueMetadataValues([
            timeRange,
            meetingProvider,
            account,
            event.calendarTitle
        ]),
        meetingService: event.meetingService,
        countdown: countdown
    )
}

/// Moved from `MenuBuilder` (was a private instance method reading
/// `self.state.timeFormat` and `I18N.instance.locale`).
///
/// The plan's original sketch for this function used a `now: Date`
/// parameter, but the actual method never read `self.now` — only
/// `self.state.timeFormat` and the current locale — so this takes
/// `timeFormat`/`locale` instead.
func eventTimePresentation(
    for event: CalenbarEventInput,
    timeFormat: CalenbarTimeFormat,
    locale: Locale,
    allDayLabel: String
) -> EventTimePresentation {
    let formatter = DateFormatter()
    formatter.locale = locale

    switch timeFormat {
    case .twelveHour:
        formatter.dateFormat = "h:mm a"
    case .twentyFourHour:
        formatter.dateFormat = "HH:mm"
    }

    guard event.isAllDay else {
        return EventTimePresentation(
            formatter: formatter,
            start: formatter.string(from: event.startDate),
            end: formatter.string(from: event.endDate)
        )
    }

    return EventTimePresentation(
        formatter: formatter,
        start: allDayLabel,
        end: ""
    )
}

/// Moved from `MenuBuilder` — only used by `meetingSummaryPresentation`.
private func firstMeaningfulMetadataValue(_ values: [String?]) -> String? {
    values.lazy
        .compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .first { !$0.isEmpty }
}

/// Moved from `MenuBuilder` — only used by `meetingSummaryPresentation`.
private func uniqueMetadataValues(_ values: [String?]) -> [String] {
    var seen = Set<String>()
    return values.compactMap { value in
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        let identity = trimmed.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        guard seen.insert(identity).inserted else { return nil }
        return trimmed
    }
}
