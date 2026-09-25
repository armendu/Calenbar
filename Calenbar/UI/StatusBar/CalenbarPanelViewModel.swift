//
//  CalenbarPanelViewModel.swift
//  MeetingBar
//

import Foundation

// MARK: - Meeting summary presentation

/// What the current/next meeting card shows; rendered by `MeetingSummaryView`.
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

    var badge: CalenbarRowBadge {
        meetingService.map(CalenbarRowBadge.service) ?? .plain
    }
}

/// An event's formatted start/end times, plus the formatter used (the menu
/// reuses it for its duration row).
struct EventTimePresentation {
    let formatter: DateFormatter
    let start: String
    let end: String
}

// MARK: - Shadow inputs

// This file is compiled into the AppKit-free `MeetingBarLogic` package so it
// can be unit-tested with `swift test`. It can't see `MBEvent`, `TimeFormat`,
// or localization (they depend on AppKit/Defaults), so these plain mirrors
// carry just what it needs. CalenbarPanelViewModel+MeetingBar.swift converts
// the real types into them.

/// The `MBEvent` fields the panel reads.
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

/// Mirror of `TimeFormat`.
enum CalenbarTimeFormat: Equatable {
    case twelveHour
    case twentyFourHour
}

/// The `StatusBarMenuState` fields the panel reads.
struct CalenbarPanelStateInput: Equatable {
    let nextEvent: CalenbarEventInput?
    let todayEvents: [CalenbarEventInput]
    let timeFormat: CalenbarTimeFormat
    /// The status bar's "show the event only within N minutes" setting,
    /// which the panel honours too.
    let showMaxTimeUntilEventEnabled: Bool
    let showMaxTimeUntilEventThresholdMinutes: Int
}

/// Already-localized strings the panel needs (see `CalenbarPanelLabels.current`).
struct CalenbarPanelLabels: Equatable {
    let noTitle: String
    let currentMeetingSectionTitle: String
    let nextMeetingSectionTitle: String
    /// Has one `%@` for the countdown, e.g. "in %@".
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
    /// Rendered dimmed so a finished event doesn't read as upcoming.
    let hasEnded: Bool

    var badge: CalenbarRowBadge {
        if isCurrent { return .live(hasMeeting: meetingService != nil) }
        if let meetingService { return .service(meetingService) }
        return .plain
    }
}

/// What the circular badge at the start of a panel row shows.
enum CalenbarRowBadge: Equatable {
    /// The event is happening now.
    case live(hasMeeting: Bool)
    /// The event has a meeting link; show that service's logo.
    case service(MeetingServices)
    /// A plain calendar event.
    case plain
}

/// Everything the glass panel renders: the summary card and today's agenda.
/// Built from the same state as the classic menu, so the two always agree.
struct CalenbarPanelViewModel: Equatable {
    var summary: MeetingSummaryPresentation?
    var agenda: [CalenbarAgendaRow]
    var emptyStateMessage: String?

    static func build(
        from state: CalenbarPanelStateInput,
        now: Date,
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

        // Same gate as the status bar's `.afterThreshold` mode. A running
        // event has a negative time-until-start, so it's never held back.
        let timeUntilStart = next.startDate.timeIntervalSince(now)
        let thresholdSeconds = TimeInterval(state.showMaxTimeUntilEventThresholdMinutes * 60)
        let isBeyondThreshold = state.showMaxTimeUntilEventEnabled && timeUntilStart >= thresholdSeconds

        guard !isBeyondThreshold else {
            // No summary card, so keep the next event in the list.
            let agenda = state.todayEvents.map { event in
                makeAgendaRow(for: event, timeFormat: state.timeFormat, locale: locale, labels: labels, now: now)
            }
            let timeLeft = StatusBarTitlePolicy.formattedTimeLeft(from: now, to: next.startDate, calendar: Calendar.current)
            let message = timeLeft.isEmpty
                ? labels.nextMeetingSectionTitle
                : "\(labels.nextMeetingSectionTitle) • \(String(format: labels.countdownFormat, timeLeft))"
            return CalenbarPanelViewModel(summary: nil, agenda: agenda, emptyStateMessage: message)
        }

        let summary = meetingSummaryPresentation(
            for: next,
            timeFormat: state.timeFormat,
            locale: locale,
            now: now,
            labels: labels
        )

        // The summary card already shows `next`, so don't list it twice.
        let agenda = state.todayEvents.filter { $0.id != next.id }.map { event in
            makeAgendaRow(for: event, timeFormat: state.timeFormat, locale: locale, labels: labels, now: now)
        }

        return CalenbarPanelViewModel(summary: summary, agenda: agenda, emptyStateMessage: nil)
    }

    private static func makeAgendaRow(
        for event: CalenbarEventInput,
        timeFormat: CalenbarTimeFormat,
        locale: Locale,
        labels: CalenbarPanelLabels,
        now: Date
    ) -> CalenbarAgendaRow {
        let time = eventTimePresentation(
            for: event,
            timeFormat: timeFormat,
            locale: locale,
            allDayLabel: labels.allDayStartLabel
        )
        return CalenbarAgendaRow(
            id: event.id,
            title: event.title.isEmpty ? labels.noTitle : event.title,
            timeRangeText: event.isAllDay ? time.start : "\(time.start) – \(time.end)",
            meetingService: event.meetingService,
            isCurrent: event.isRunning(at: now),
            hasEnded: event.endDate <= now
        )
    }
}

// MARK: - Shared with MenuBuilder

extension CalenbarEventInput {
    func isRunning(at now: Date) -> Bool {
        startDate <= now && endDate > now
    }
}

/// The meeting card's content. Used by both the glass panel and the classic menu.
func meetingSummaryPresentation(
    for event: CalenbarEventInput,
    timeFormat: CalenbarTimeFormat,
    locale: Locale,
    now: Date,
    labels: CalenbarPanelLabels
) -> MeetingSummaryPresentation {
    let isCurrent = event.isRunning(at: now)
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

private func firstMeaningfulMetadataValue(_ values: [String?]) -> String? {
    values.lazy
        .compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .first { !$0.isEmpty }
}

/// Drops blanks and case/diacritic-insensitive duplicates, keeping order.
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
