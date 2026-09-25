//
//  AppearanceTab.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 13.01.2021.
//  Copyright © 2021 Andrii Leitsius. All rights reserved.
//

import Defaults
import SwiftUI

struct AppearanceTab: View {
    var body: some View {
        PreferencesGroupedForm {
            EventsSection()
            StatusBarSection()
            MenuSection()
        }
    }
}

// MARK: - Events

struct EventsSection: View {
    @Default(.declinedEventsAppereance) var declinedEventsAppereance
    @Default(.personalEventsAppereance) var personalEventsAppereance
    @Default(.pastEventsAppereance) var pastEventsAppereance
    @Default(.allDayEvents) var allDayEvents
    @Default(.nonAllDayEvents) var nonAllDayEvents
    @Default(.showPendingEvents) var showPendingEvents
    @Default(.showTentativeEvents) var showTentativeEvents
    @Default(.showEventsForPeriod) var showEventsForPeriod

    var body: some View {
        Section(header: Text("preferences_appearance_events_title".loco())) {
            Picker(
                preferenceLabel("preferences_appearance_events_show_events_for_title"),
                selection: $showEventsForPeriod
            ) {
                Text("preferences_appearance_events_show_events_for_today_value".loco())
                    .tag(ShowEventsForPeriod.today)
                Text("preferences_appearance_events_show_events_for_today_tomorrow_value".loco())
                    .tag(ShowEventsForPeriod.today_n_tomorrow)
            }
        }

        Section {
            Picker(
                preferenceLabel("preferences_appearance_events_all_day_title"),
                selection: $allDayEvents
            ) {
                Text("preferences_appearance_events_value_show".loco())
                    .tag(AlldayEventsAppereance.show)
                Text("preferences_appearance_events_value_only_with_link".loco())
                    .tag(AlldayEventsAppereance.show_with_meeting_link_only)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(AlldayEventsAppereance.hide)
            }

            Picker(
                preferenceLabel("preferences_appearance_events_no_meeting_link_title"),
                selection: $nonAllDayEvents
            ) {
                Text("preferences_appearance_events_value_show".loco())
                    .tag(NonAlldayEventsAppereance.show)
                Text("preferences_appearance_events_value_as_inactive".loco())
                    .tag(NonAlldayEventsAppereance.show_inactive_without_meeting_link)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(NonAlldayEventsAppereance.hide_without_meeting_link)
            }

            Picker(
                preferenceLabel("preferences_appearance_events_without_guest_title"),
                selection: $personalEventsAppereance
            ) {
                Text("preferences_appearance_events_value_show".loco())
                    .tag(PastEventsAppereance.show_active)
                Text("preferences_appearance_events_value_as_inactive".loco())
                    .tag(PastEventsAppereance.show_inactive)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(PastEventsAppereance.hide)
            }
        }

        Section {
            Picker(
                preferenceLabel("preferences_appearance_events_pending_title"),
                selection: $showPendingEvents
            ) {
                Text("preferences_appearance_events_value_show".loco())
                    .tag(PendingEventsAppereance.show)
                Text("preferences_appearance_events_value_as_underlined".loco())
                    .tag(PendingEventsAppereance.show_underlined)
                Text("preferences_appearance_events_value_as_inactive".loco())
                    .tag(PendingEventsAppereance.show_inactive)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(PendingEventsAppereance.hide)
            }

            Picker(
                preferenceLabel("preferences_appearance_events_tentative_title"),
                selection: $showTentativeEvents
            ) {
                Text("preferences_appearance_events_value_show".loco())
                    .tag(TentativeEventsAppereance.show)
                Text("preferences_appearance_events_value_as_underlined".loco())
                    .tag(TentativeEventsAppereance.show_underlined)
                Text("preferences_appearance_events_value_as_inactive".loco())
                    .tag(TentativeEventsAppereance.show_inactive)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(TentativeEventsAppereance.hide)
            }

            Picker(
                preferenceLabel("preferences_appearance_events_declined_title"),
                selection: $declinedEventsAppereance
            ) {
                Text("preferences_appearance_events_value_with_strikethrough".loco())
                    .tag(DeclinedEventsAppereance.strikethrough)
                Text("preferences_appearance_events_value_as_inactive".loco())
                    .tag(DeclinedEventsAppereance.show_inactive)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(DeclinedEventsAppereance.hide)
            }

            Picker(
                preferenceLabel("preferences_appearance_events_past_title"),
                selection: $pastEventsAppereance
            ) {
                Text("preferences_appearance_events_value_show".loco())
                    .tag(PastEventsAppereance.show_active)
                Text("preferences_appearance_events_value_as_inactive".loco())
                    .tag(PastEventsAppereance.show_inactive)
                Text("preferences_appearance_events_value_hide".loco())
                    .tag(PastEventsAppereance.hide)
            }
        }
    }
}

// MARK: - Status bar

/// Presets for "show the event only within…", like Notion Calendar's picker.
/// Stored in the existing threshold keys; `.always` turns the threshold off.
enum ShowMeetingThresholdOption: Int, CaseIterable {
    case always = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case fourHours = 240
    case eightHours = 480

    var label: String {
        switch self {
        case .always: return "calenbar_threshold_always".loco()
        case .fiveMinutes: return "calenbar_threshold_5_minutes".loco()
        case .tenMinutes: return "calenbar_threshold_10_minutes".loco()
        case .fifteenMinutes: return "calenbar_threshold_15_minutes".loco()
        case .thirtyMinutes: return "calenbar_threshold_30_minutes".loco()
        case .oneHour: return "calenbar_threshold_1_hour".loco()
        case .twoHours: return "calenbar_threshold_2_hours".loco()
        case .fourHours: return "calenbar_threshold_4_hours".loco()
        case .eightHours: return "calenbar_threshold_8_hours".loco()
        }
    }
}

struct StatusBarSection: View {
    @Default(.eventTitleIconFormat) var eventTitleIconFormat
    @Default(.eventTitleFormat) var eventTitleFormat
    @Default(.eventTimeFormat) var eventTimeFormat
    @Default(.statusbarEventTitleLength) var statusbarEventTitleLength
    @Default(.showEventMaxTimeUntilEventThreshold) var showEventMaxTimeUntilEventThreshold
    @Default(.showEventMaxTimeUntilEventEnabled) var showEventMaxTimeUntilEventEnabled
    @Default(.ongoingEventVisibility) var ongoingEventVisibility

    /// Maps the picker onto the enabled flag and minutes keys.
    private var showMeetingThresholdBinding: Binding<ShowMeetingThresholdOption> {
        Binding(
            get: {
                guard showEventMaxTimeUntilEventEnabled else { return .always }
                return ShowMeetingThresholdOption(rawValue: showEventMaxTimeUntilEventThreshold) ?? .oneHour
            },
            set: { newValue in
                if newValue == .always {
                    showEventMaxTimeUntilEventEnabled = false
                } else {
                    showEventMaxTimeUntilEventEnabled = true
                    showEventMaxTimeUntilEventThreshold = newValue.rawValue
                }
            }
        )
    }

    var body: some View {
        Section(header: Text("preferences_appearance_status_bar_title".loco())) {
            Picker(
                preferenceLabel("preferences_appearance_status_bar_icon_title"),
                selection: $eventTitleIconFormat
            ) {
                HStack {
                    Image(nsImage: MenuStyleConstants.todaysDateIcon(pointSize: 16))
                        .resizable()
                        .frame(width: 16.0, height: 16.0)
                    Text("preferences_appearance_status_bar_icon_calendar_icon_value".loco())
                }.tag(EventTitleIconFormat.calendar)

                HStack {
                    Image(nsImage: getImage(iconName: EventTitleIconFormat.appicon.rawValue))
                        .resizable()
                        .frame(width: 16.0, height: 16.0)
                    Text("preferences_appearance_status_bar_icon_app_icon_value".loco())
                }.tag(EventTitleIconFormat.appicon)

                HStack {
                    Image(nsImage: getImage(iconName: EventTitleIconFormat.eventtype.rawValue))
                        .resizable()
                        .frame(width: 16.0, height: 16.0)
                    Text("preferences_appearance_status_bar_icon_specific_icon_value".loco())
                }.tag(EventTitleIconFormat.eventtype)

                HStack {
                    Image(nsImage: getImage(iconName: EventTitleIconFormat.none.rawValue))
                        .resizable()
                        .frame(width: 16.0, height: 16.0)
                    Text("preferences_appearance_status_bar_icon_no_icon_value".loco())
                }.tag(EventTitleIconFormat.none)
            }

            Picker(
                preferenceLabel("preferences_appearance_status_bar_title_title"),
                selection: $eventTitleFormat
            ) {
                Text("preferences_appearance_status_bar_title_event_title_value".loco())
                    .tag(EventTitleFormat.show)
                Text("preferences_appearance_status_bar_title_generic_value".loco())
                    .tag(EventTitleFormat.generic)
                Text("preferences_appearance_status_bar_title_dot_value".loco())
                    .tag(EventTitleFormat.dot)
                Text("preferences_appearance_status_bar_title_hide_value".loco())
                    .tag(EventTitleFormat.none)
            }

            HStack {
                Spacer()
                Stepper(
                    value: $statusbarEventTitleLength,
                    in: statusbarEventTitleLengthLimits.min ... statusbarEventTitleLengthLimits.max,
                    step: 5
                ) {
                    Text(
                        "preferences_appearance_status_bar_title_shorten_stepper".loco(
                            statusbarEventTitleLength)
                    )
                    .monospacedDigit()
                }
                .fixedSize()
            }
            .padding(.leading, 16)
            .disabled(eventTitleFormat != .show)

            Picker(
                preferenceLabel("preferences_appearance_status_bar_time_title"),
                selection: $eventTimeFormat
            ) {
                ForEach(PreferencesStatusBarTimeOption.allCases, id: \.format) { option in
                    Text(option.titleKey.loco()).tag(option.format)
                }
            }
        }

        Section {
            Picker(
                preferenceLabel("preferences_appearance_status_bar_next_event_toggle"),
                selection: showMeetingThresholdBinding
            ) {
                ForEach(ShowMeetingThresholdOption.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }

            Picker(
                preferenceLabel("preferences_appearance_status_bar_ongoing_title"),
                selection: $ongoingEventVisibility
            ) {
                Text("preferences_appearance_status_bar_ongoing_time_immediate_value".loco())
                    .tag(OngoingEventVisibility.hideImmediateAfter)
                Text("preferences_appearance_status_bar_ongoing_time_ten_after_value".loco())
                    .tag(OngoingEventVisibility.showTenMinAfter)
                Text("preferences_appearance_status_bar_ongoing_time_ten_before_next_value".loco())
                    .tag(OngoingEventVisibility.showTenMinBeforeNext)
            }
        }
    }

    func getImage(iconName: String) -> NSImage {
        let icon = NSImage(named: iconName)
        icon!.size = NSSize(width: 16, height: 16)
        return icon!
    }
}

// MARK: - Menu

struct MenuSection: View {
    @Default(.shortenEventTitle) var shortenEventTitle
    @Default(.menuEventTitleLength) var menuEventTitleLength
    @Default(.showEventEndTime) var showEventEndTime
    @Default(.showEventDetails) var showEventDetails
    @Default(.showMeetingServiceIcon) var showMeetingServiceIcon
    @Default(.showEventCalendarColor) var showEventCalendarColor
    @Default(.showTimelineInMenu) var showTimelineInMenu

    var body: some View {
        Section(header: Text("preferences_appearance_menu_title".loco())) {
            Toggle(
                preferenceLabel("preferences_appearance_menu_show_timeline_toggle"),
                isOn: $showTimelineInMenu
            )
        }

        Section(header: Text(preferenceLabel("preferences_appearance_menu_show_event_title"))) {
            Toggle(
                preferenceLabel("preferences_appearance_menu_show_event_end_time_value"),
                isOn: $showEventEndTime
            )
            Toggle(
                preferenceLabel("preferences_appearance_menu_show_event_icon_value"),
                isOn: $showMeetingServiceIcon
            )
            Toggle(
                preferenceLabel("preferences_appearance_menu_show_event_calendar_color_value"),
                isOn: $showEventCalendarColor
            )
            Toggle(
                preferenceLabel("preferences_appearance_menu_show_event_details_value"),
                isOn: $showEventDetails
            )
        }

        Section {
            Toggle(
                preferenceLabel("preferences_appearance_menu_shorten_event_title_toggle"),
                isOn: $shortenEventTitle
            )

            HStack {
                Spacer()
                Stepper(
                    value: $menuEventTitleLength,
                    in: 20 ... 100,
                    step: 5
                ) {
                    Text(
                        "preferences_appearance_menu_shorten_event_title_stepper".loco(
                            menuEventTitleLength)
                    )
                    .monospacedDigit()
                }
                .fixedSize()
            }
            .padding(.leading, 16)
            .disabled(!shortenEventTitle)
        }
    }
}

#Preview {
    AppearanceTab().frame(width: 700, height: 620)
}
