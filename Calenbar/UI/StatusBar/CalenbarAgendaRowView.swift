//
//  CalenbarAgendaRowView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// One row of the panel's "today" agenda. Plain content rather than glass:
/// it sits inside the agenda's glass tile, and glass shouldn't stack on glass.
struct CalenbarAgendaRowView: View {
    let row: CalenbarAgendaRow
    var onSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            CalenbarEventBadge(badge: row.badge)

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
        .opacity(row.hasEnded ? 0.45 : 1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calenbarRowBubble(hovered: isHovered)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.timeRangeText)")
        .accessibilityHint(onSelect != nil ? "calenbar_panel_agenda_row_accessibility_hint".loco() : "")
        .calenbarRowHover(pointingHand: onSelect != nil) { isHovered = $0 }
        .onTapGesture { onSelect?() }
        .calenbarAccessibilityButton(onSelect)
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
                isCurrent: true,
                hasEnded: false
            )
        )
        CalenbarAgendaRowView(
            row: CalenbarAgendaRow(
                id: "2",
                title: "1:1 with manager",
                timeRangeText: "11:00 – 11:30",
                meetingService: .meet,
                isCurrent: false,
                hasEnded: false
            )
        )
        CalenbarAgendaRowView(
            row: CalenbarAgendaRow(
                id: "3",
                title: "Morning sync (finished)",
                timeRangeText: "08:00 – 08:15",
                meetingService: nil,
                isCurrent: false,
                hasEnded: true
            )
        )
    }
    .padding()
}
