//
//  CalenbarAgendaRowView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// One row of the glass panel's "today" agenda list. Deliberately plain
/// (non-glass) content — it sits inside the panel's agenda glass tile (see
/// `CalenbarGlassPanelView.agendaTile`), and per Apple's Liquid Glass
/// guidance, individual rows inside a glass tile shouldn't carry their own
/// separate glass effect ("glass cannot sample other glass").
struct CalenbarAgendaRowView: View {
    let row: CalenbarAgendaRow
    var onSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // A small live dot reads faster than the icon/weight change alone
            // for "this is happening right now" — same visual language as
            // the running-meeting indicator system Calendar widgets use.
            Circle()
                .fill(row.isCurrent ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)

            Image(nsImage: getIconForMeetingService(row.meetingService))
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .opacity(row.isCurrent ? 1 : 0.7)

            Text(row.title)
                .font(.subheadline.weight(row.isCurrent ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(row.timeRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.timeRangeText)")
        .accessibilityHint(onSelect != nil ? "calenbar_panel_agenda_row_accessibility_hint".loco() : "")
        .onHover { hovering in
            isHovered = hovering
            guard onSelect != nil else { return }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture { onSelect?() }
    }
}

#Preview {
    VStack(spacing: 2) {
        CalenbarAgendaRowView(
            row: CalenbarAgendaRow(
                id: "1",
                title: "Stand Up",
                timeRangeText: "10:00 – 10:15",
                meetingService: .zoom,
                isCurrent: true
            )
        )
        CalenbarAgendaRowView(
            row: CalenbarAgendaRow(
                id: "2",
                title: "1:1 with manager",
                timeRangeText: "11:00 – 11:30",
                meetingService: .meet,
                isCurrent: false
            )
        )
    }
    .padding()
}
