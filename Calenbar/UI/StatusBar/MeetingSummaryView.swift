//
//  MeetingSummaryView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// The current/next meeting card. Shown in the glass panel's summary tile and
/// as a row of the classic menu. Renders a `MeetingSummaryPresentation`.
struct MeetingSummaryView: View {
    let presentation: MeetingSummaryPresentation
    var onJoin: (() -> Void)?

    @State private var isHovered = false

    static let preferredWidth: CGFloat = 280
    static let preferredHeight: CGFloat = 66

    var body: some View {
        HStack(spacing: 11) {
            CalenbarEventBadge(badge: presentation.badge, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.sectionTitleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(presentation.eventTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(presentation.metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let onJoin {
                Spacer(minLength: 8)
                // The system's prominent glass button: the panel's one
                // control with a colored background, as the HIG suggests.
                Button("notifications_meetingbar_join_event_action".loco(), action: onJoin)
                    .buttonStyle(.glassProminent)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // NSMenu sizes itself from this row's ideal width, which for a long
        // title is the whole title on one line. Fixing the ideal width keeps
        // the menu narrow, while maxWidth still lets the row fill whatever
        // width the menu or glass tile actually has.
        .frame(
            minWidth: 0, idealWidth: Self.preferredWidth, maxWidth: .infinity,
            minHeight: Self.preferredHeight, alignment: .leading
        )
        // Follows the corners of the tile around it (the glass panel's summary
        // tile); in the classic menu there's no tile, so the minimum applies.
        .background(
            ConcentricRectangle(corners: .concentric(minimum: 8))
                .fill(isHovered && onJoin != nil ? Color.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .calenbarRowHover(pointingHand: onJoin != nil) { isHovered = $0 }
        .onTapGesture { onJoin?() }
        .accessibilityElement(children: .combine)
        .calenbarAccessibilityButton(onJoin)
    }
}

#Preview {
    MeetingSummaryView(
        presentation: MeetingSummaryPresentation(
            sectionTitle: "Next meeting",
            eventTitle: "Weekly product sync",
            metadata: ["10:00 – 10:30", "Zoom", "Work"],
            meetingService: .zoom,
            countdown: "in 25m"
        ),
        onJoin: {}
    )
}
