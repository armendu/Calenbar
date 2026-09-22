//
//  CalenbarGlassPanelView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// The primary Liquid Glass surface shown on left-click of the status item
/// (see `CalenbarPanelController`). Covers the high-frequency flow only —
/// current/next meeting summary, Join, and today's agenda.
///
/// Right-click's existing behavior (an instant "join next meeting" shortcut)
/// is untouched by this panel — it was never a menu trigger to begin with
/// (confirmed by reading `StatusBarItemController.statusMenuBarAction`), so
/// there's no "classic menu on right-click" to preserve there. Instead, the
/// full classic `NSMenu` (with every other MeetingBar feature: bookmarks,
/// attendees, alternate links, preferences, etc.) stays reachable via the
/// "More…" row below, so nothing existing is lost by adding this panel.
///
/// Exactly one `.glassEffect()` is applied, to the whole container. Per
/// Apple's Liquid Glass guidance, glass is reserved for the single
/// navigation-layer surface, not stacked on individual pieces of content
/// inside it — so `MeetingSummaryView`'s existing accent-color capsule Join
/// button and `CalenbarAgendaRowView`'s rows stay plain (non-glass) by
/// design, not by oversight.
struct CalenbarGlassPanelView: View {
    let viewModel: CalenbarPanelViewModel
    let onJoin: () -> Void
    let onSelectAgendaRow: (CalenbarAgendaRow) -> Void
    let onShowClassicMenu: () -> Void

    static let width: CGFloat = 380

    @State private var isMoreHovered = false

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 6) {
                if let summary = viewModel.summary {
                    MeetingSummaryView(
                        presentation: summary,
                        providerIcon: getIconForMeetingService(summary.meetingService),
                        onJoin: onJoin
                    )
                } else {
                    Text(viewModel.emptyStateMessage ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }

                if !viewModel.agenda.isEmpty {
                    Divider()
                        .padding(.horizontal, 8)
                    VStack(spacing: 0) {
                        ForEach(viewModel.agenda) { row in
                            CalenbarAgendaRowView(row: row) {
                                onSelectAgendaRow(row)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Divider()
                    .padding(.horizontal, 8)
                moreRow
            }
            .padding(.vertical, 6)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
    }

    private var moreRow: some View {
        HStack {
            Text("More…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isMoreHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isMoreHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture(perform: onShowClassicMenu)
        .accessibilityLabel("More options")
        .accessibilityHint("Opens the full menu")
    }
}

#Preview("With agenda") {
    CalenbarGlassPanelView(
        viewModel: CalenbarPanelViewModel(
            summary: MeetingSummaryPresentation(
                sectionTitle: "Next meeting",
                eventTitle: "Weekly product sync",
                metadata: ["10:00 – 10:30", "Zoom", "Work"],
                meetingService: .zoom,
                countdown: "in 4m"
            ),
            agenda: [
                CalenbarAgendaRow(id: "1", title: "Weekly product sync", timeRangeText: "10:00 – 10:30", meetingService: .zoom, isCurrent: false),
                CalenbarAgendaRow(id: "2", title: "1:1 with manager", timeRangeText: "11:00 – 11:30", meetingService: .meet, isCurrent: false)
            ],
            emptyStateMessage: nil
        ),
        onJoin: {},
        onSelectAgendaRow: { _ in },
        onShowClassicMenu: {}
    )
    .padding(40)
}

#Preview("Empty state") {
    CalenbarGlassPanelView(
        viewModel: CalenbarPanelViewModel(
            summary: nil,
            agenda: [],
            emptyStateMessage: "No more meetings today"
        ),
        onJoin: {},
        onSelectAgendaRow: { _ in },
        onShowClassicMenu: {}
    )
    .padding(40)
}
