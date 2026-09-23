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

    /// The real Calendar.app icon, which macOS renders with today's actual
    /// date baked in (the same "torn calendar page" trick Calendar.app's own
    /// icon and several third-party menu-bar calendar apps use) — used for
    /// the empty state instead of a generic checkmark, since "today's date"
    /// is a much more immediately legible signal than a tick mark for "no
    /// more meetings today."
    private static var todaysCalendarIcon: NSImage {
        let candidatePaths = [
            "/System/Applications/Calendar.app",
            "/Applications/Calendar.app"
        ]
        for path in candidatePaths where FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        // Calendar.app should always be present on macOS, but fall back to a
        // generic symbol rather than crash if it's ever missing/renamed.
        return NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 18, height: 18))
    }

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
                // Deliberately compact — an empty state is the lowest-
                // information moment in the panel and shouldn't be the
                // visually heaviest thing in it. Sized to match a single
                // agenda row (CalenbarAgendaRowView), not a full card.
                HStack(spacing: 8) {
                    Image(nsImage: Self.todaysCalendarIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(viewModel.emptyStateMessage ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .glassEffect(.regular, in: Self.tileShape)
    }

    private var agendaTile: some View {
        VStack(spacing: 0) {
            if !viewModel.agenda.isEmpty {
                // No extra horizontal padding here beyond CalenbarAgendaRowView's
                // own: that view already insets to 16pt to match the summary
                // tile's left edge (its 12pt + the 4pt CalenbarGlassPanelView
                // adds around it) — an additional wrapper here would push
                // agenda rows further right than the summary card's text.
                VStack(spacing: 2) {
                    ForEach(viewModel.agenda) { row in
                        CalenbarAgendaRowView(row: row) {
                            onSelectAgendaRow(row)
                        }
                    }
                }
                .padding(.top, 6)

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
        MoreRow(onShowClassicMenu: onShowClassicMenu)
    }
}

/// The "More…" row. A plain hover-aware row (not a `Button` + `ButtonStyle`):
/// a ButtonStyle only exposes `isPressed`, so the previous version had no
/// hover state at all — the row lit up only for the instant of a click. This
/// mirrors `CalenbarAgendaRowView` exactly so both rows in the panel share
/// one hover affordance.
private struct MoreRow: View {
    let onShowClassicMenu: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("calenbar_panel_more".loco())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calenbarRowHoverHighlight(isHovered)
        .contentShape(Rectangle())
        .accessibilityLabel("calenbar_panel_more_accessibility_label".loco())
        .accessibilityHint("calenbar_panel_more_accessibility_hint".loco())
        .calenbarRowHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture(perform: onShowClassicMenu)
    }
}

/// Shared hover fill for the panel's plain (non-glass) rows — an inset
/// rounded pill, so the highlight sits well inside the glass tile's rounded
/// corners rather than as a flush rectangle butted against its straight
/// edges. Insets on all four sides and uses a large radius so it reads
/// clearly as a rounded pill, not a band. Applied identically by
/// `CalenbarAgendaRowView` and `MoreRow` so every row hovers the same way.
extension View {
    func calenbarRowHoverHighlight(_ isHovered: Bool) -> some View {
        background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.15 : 0))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
    }
}

/// Reliable hover detection for views inside the glass panel.
///
/// SwiftUI's own `.onHover` installs a tracking area whose activation is
/// tied to the window being key/active. This panel is a `.nonactivatingPanel`
/// that deliberately never becomes key (see `CalenbarPanelController`), so
/// `.onHover` fires inconsistently — the highlight would stick, or not
/// appear until the whole app happened to be active. An explicit
/// `NSTrackingArea` with `.activeAlways` fires mouse enter/exit regardless of
/// key/active state, which is exactly what a status-bar popup needs. The
/// backing view hit-tests as transparent so taps still reach SwiftUI.
extension View {
    func calenbarRowHover(_ onChange: @escaping (Bool) -> Void) -> some View {
        overlay(CalenbarHoverTracker(onChange: onChange))
    }
}

private struct CalenbarHoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingView)?.onChange = onChange
    }

    final class TrackingView: NSView {
        var onChange: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea { removeTrackingArea(existing) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) { onChange?(true) }
        override func mouseExited(with event: NSEvent) { onChange?(false) }

        // Transparent to clicks: the SwiftUI content underneath keeps its
        // own tap handling; this overlay only observes the pointer.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
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
                CalenbarAgendaRow(id: "1", title: "Weekly product sync", timeRangeText: "10:00 – 10:30", meetingService: .zoom, isCurrent: false, hasEnded: true),
                CalenbarAgendaRow(id: "2", title: "1:1 with manager", timeRangeText: "11:00 – 11:30", meetingService: .meet, isCurrent: false, hasEnded: false)
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
