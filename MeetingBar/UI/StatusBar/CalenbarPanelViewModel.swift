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
///
/// This mirrors how `MeetingServices` was relocated into
/// `MeetingLinkDetector.swift` for the same reason: "enum lives [there] so
/// it can be reached from the hostless logic target."
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
/// agenda rows. Built from the same `StatusBarMenuState` that drives the
/// existing `MenuBuilder`-based dropdown, so both stay in sync.
struct CalenbarPanelViewModel: Equatable {
    var summary: MeetingSummaryPresentation?
    var agenda: [CalenbarAgendaRow]
    var emptyStateMessage: String?

    static func build(
        from state: StatusBarMenuState,
        now: Date,
        isFantasticalInstalled: Bool
    ) -> CalenbarPanelViewModel {
        guard let next = state.nextEvent else {
            return CalenbarPanelViewModel(
                summary: nil,
                agenda: [],
                emptyStateMessage: "status_bar_control_no_upcoming".loco()
            )
        }

        let summary = meetingSummaryPresentation(
            for: next,
            state: state,
            now: now,
            isFantasticalInstalled: isFantasticalInstalled
        )

        let agenda = state.todayEvents.map { event -> CalenbarAgendaRow in
            let time = eventTimePresentation(for: event, timeFormat: state.timeFormat)
            let isCurrent = event.startDate <= now && event.endDate > now
            return CalenbarAgendaRow(
                id: event.id,
                title: event.title.isEmpty ? "status_bar_no_title".loco() : event.title,
                timeRangeText: event.isAllDay ? time.start : "\(time.start) – \(time.end)",
                meetingService: event.meetingLink?.service,
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
/// instead of its own (removed) method.
///
/// `isFantasticalInstalled` is threaded through for signature parity with
/// `CalenbarPanelViewModel.build` (which needs it for other panel sections);
/// the summary card itself does not use it, matching the original method's
/// behavior exactly.
func meetingSummaryPresentation(
    for event: MBEvent,
    state: StatusBarMenuState,
    now: Date,
    isFantasticalInstalled: Bool
) -> MeetingSummaryPresentation {
    let isCurrent = event.startDate <= now && event.endDate > now
    let eventTitle = event.title.isEmpty
        ? "status_bar_no_title".loco()
        : event.title
    let time = eventTimePresentation(for: event, timeFormat: state.timeFormat)
    let timeRange = event.isAllDay
        ? time.start
        : "\(time.start) – \(time.end)"
    let meetingProvider = event.meetingLink?.service
        .flatMap(MeetingProvider.provider(for:))?
        .displayName
    let account = firstMeaningfulMetadataValue([
        event.calendar.email,
        event.calendar.source == "unknown" ? nil : event.calendar.source,
        event.organizer?.email
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
        countdown = timeLeft.isEmpty ? nil : "status_bar_event_status_in".loco(timeLeft)
    }

    return MeetingSummaryPresentation(
        sectionTitle: isCurrent
            ? "status_bar_control_current_meeting".loco()
            : "status_bar_control_next_meeting".loco(),
        eventTitle: eventTitle,
        metadata: uniqueMetadataValues([
            timeRange,
            meetingProvider,
            account,
            event.calendar.title
        ]),
        meetingService: event.meetingLink?.service,
        countdown: countdown
    )
}

/// Moved from `MenuBuilder` (was a private instance method reading
/// `self.state.timeFormat`).
///
/// The plan's original sketch for this function used a `now: Date`
/// parameter, but the actual method never read `self.now` — only
/// `self.state.timeFormat` — so this takes `timeFormat` instead of `now`.
func eventTimePresentation(for event: MBEvent, timeFormat: TimeFormat) -> EventTimePresentation {
    let formatter = DateFormatter()
    formatter.locale = I18N.instance.locale

    switch timeFormat {
    case .am_pm:
        formatter.dateFormat = "h:mm a"
    case .military:
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
        start: "status_bar_event_start_time_all_day".loco(),
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
