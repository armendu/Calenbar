//
//  CalenbarPanelViewModel+MeetingBar.swift
//  MeetingBar
//

import Foundation

// Adapters from the real, AppKit/Defaults-coupled production types
// (`MBEvent`, `StatusBarMenuState`, `TimeFormat`) to the pure shadow types
// `CalenbarPanelViewModel.swift` operates on. Mirrors
// `StatusBarPresentation+MeetingBar.swift`'s `init(_ event: MBEvent)` /
// `.current` pattern exactly. This file is app-target only — it is not
// listed in Package.swift's `MeetingBarLogic` sources.

extension CalenbarEventInput {
    init(_ event: MBEvent) {
        self.init(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            meetingService: event.meetingLink?.service,
            calendarEmail: event.calendar.email,
            calendarSource: event.calendar.source,
            calendarTitle: event.calendar.title,
            organizerEmail: event.organizer?.email
        )
    }
}

extension CalenbarTimeFormat {
    init(_ format: TimeFormat) {
        switch format {
        case .am_pm:
            self = .twelveHour
        case .military:
            self = .twentyFourHour
        }
    }
}

extension CalenbarPanelStateInput {
    init(_ state: StatusBarMenuState) {
        self.init(
            nextEvent: state.nextEvent.map(CalenbarEventInput.init),
            todayEvents: state.todayEvents.map(CalenbarEventInput.init),
            timeFormat: CalenbarTimeFormat(state.timeFormat),
            showMaxTimeUntilEventEnabled: state.events.showEventMaxTimeUntilEventEnabled,
            showMaxTimeUntilEventThresholdMinutes: state.events.showEventMaxTimeUntilEventThreshold
        )
    }
}

extension CalenbarPanelLabels {
    /// Snapshot of the `.loco()`-localized strings the pure panel logic
    /// needs. Mirrors `StatusBarTitleLabels.current`.
    static var current: CalenbarPanelLabels {
        CalenbarPanelLabels(
            noTitle: "status_bar_no_title".loco(),
            currentMeetingSectionTitle: "status_bar_control_current_meeting".loco(),
            nextMeetingSectionTitle: "status_bar_control_next_meeting".loco(),
            // Raw (unsubstituted) format string, e.g. "in %@" — matches how
            // StatusBarTitleLabels.upcomingEventTimeFormat is populated.
            countdownFormat: "status_bar_event_status_in".loco(),
            allDayStartLabel: "status_bar_event_start_time_all_day".loco(),
            noUpcomingMessage: "status_bar_control_no_upcoming".loco()
        )
    }
}
