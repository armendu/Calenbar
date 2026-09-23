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
/// Modeled on Control Center's own layout: distinct glass **tiles** for each
/// logical group (summary, agenda) sharing one `GlassEffectContainer`,
/// rather than one monolithic glass rectangle wrapping everything — this is
/// what makes system glass surfaces read as a coherent group of controls
/// instead of a single translucent card. Content *inside* each tile stays
/// plain (non-glass): `MeetingSummaryView`'s existing accent-color capsule
/// Join button and `CalenbarAgendaRowView`'s rows aren't independently
/// glass, per Apple's "glass is the navigation-layer surface itself, not
/// stacked on content within it" guidance — only the tiles that group them
/// are.
struct CalenbarGlassPanelView: View {
    let viewModel: CalenbarPanelViewModel
    let onJoin: () -> Void
    let onSelectAgendaRow: (CalenbarAgendaRow) -> Void
    let onShowClassicMenu: () -> Void

    /// Shares `MeetingSummaryView.preferredWidth` rather than a second
    /// independent literal, so the panel and its embedded summary card
    /// can't silently drift out of alignment if one changes.
    static let width: CGFloat = MeetingSummaryView.preferredWidth

    private static let tileShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                summaryTile
                // Always shown, even with an empty agenda: it's the only
                // path to the classic menu (the "More…" row), so it can't
                // be conditional on there being agenda rows to display.
                agendaTile
            }
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
    }

    private var summaryTile: some View {
        Group {
            if let summary = viewModel.summary {
                MeetingSummaryView(
                    presentation: summary,
                    providerIcon: getIconForMeetingService(summary.meetingService),
                    onJoin: onJoin
                )
                // MeetingSummaryView's own padding (12h/6v) was tuned for a
                // flat NSMenuItem row with square corners, not for being the
                // sole content of a 20pt continuous-corner glass tile —
                // without this, its text/icon would sit right at the
                // rounded edge. Added here rather than in the shared file,
                // since MeetingSummaryView is also used as-is inside the
                // classic NSMenu (MenuBuilder.makeMeetingSummaryItem), where
                // this extra inset would be wrong.
                .padding(4)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Text(viewModel.emptyStateMessage ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
        }
        .glassEffect(.regular, in: Self.tileShape)
    }

    private var agendaTile: some View {
        VStack(spacing: 0) {
            if !viewModel.agenda.isEmpty {
                VStack(spacing: 2) {
                    ForEach(viewModel.agenda) { row in
                        CalenbarAgendaRowView(row: row) {
                            onSelectAgendaRow(row)
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 4)

                Divider()
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }
            moreRow
        }
        .padding(.bottom, 4)
        .glassEffect(.regular, in: Self.tileShape)
    }

    private var moreRow: some View {
        Button(action: onShowClassicMenu) {
            HStack(spacing: 6) {
                Text("calenbar_panel_more".loco())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(CalenbarRowButtonStyle())
        .accessibilityLabel("calenbar_panel_more_accessibility_label".loco())
        .accessibilityHint("calenbar_panel_more_accessibility_hint".loco())
    }
}

/// Shared hover/press affordance for plain (non-glass) rows sitting inside a
/// glass tile — a subtle fill, not another material, so it doesn't compete
/// with the tile's own glass. Matches `CalenbarAgendaRowView`'s existing
/// hover treatment so every row in the panel feels like the same control.
private struct CalenbarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0))
            )
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
