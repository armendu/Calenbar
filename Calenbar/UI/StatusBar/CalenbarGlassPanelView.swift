//
//  CalenbarGlassPanelView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// The Liquid Glass panel shown on left-click of the status item: the
/// current/next meeting, Join, and today's agenda. Everything else lives in
/// the classic menu, reachable through the "More…" row. Laid out like Control
/// Center: separate glass tiles in one `GlassEffectContainer`, with plain
/// content inside each tile.
struct CalenbarGlassPanelView: View {
    let viewModel: CalenbarPanelViewModel
    let onJoin: () -> Void
    let onSelectAgendaRow: (CalenbarAgendaRow) -> Void
    let onShowClassicMenu: () -> Void

    static let width: CGFloat = MeetingSummaryView.preferredWidth

    private static let tileShape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    /// Gap between a tile's edge and the rows inside it, the same on every side.
    static let tileInset: CGFloat = 6

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                summaryTile
                // Always shown: "More…" is the only way into the classic menu.
                agendaTile
            }
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
    }

    private var summaryTile: some View {
        Group {
            if let summary = viewModel.summary {
                MeetingSummaryView(presentation: summary, onJoin: onJoin)
                    // Inset from the tile's rounded edge. Not in MeetingSummaryView
                    // itself, which is also used flat in the classic menu.
                    .padding(4)
            } else {
                HStack(spacing: 10) {
                    CalenbarBadge {
                        Image(nsImage: MenuStyleConstants.todaysDateIcon(pointSize: 15))
                            .renderingMode(.template)
                            .modifier(CalenbarIconColor())
                    }
                    Text(viewModel.emptyStateMessage ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .containerShape(Self.tileShape)
        .glassEffect(.regular, in: Self.tileShape)
    }

    private var agendaTile: some View {
        VStack(spacing: 4) {
            ForEach(viewModel.agenda) { row in
                CalenbarAgendaRowView(row: row) {
                    onSelectAgendaRow(row)
                }
            }
            MoreRow(onShowClassicMenu: onShowClassicMenu)
        }
        .padding(Self.tileInset)
        // Rows draw ConcentricRectangle bubbles, which take their corners from
        // this shape: tile radius minus the inset, so the curves stay parallel.
        .containerShape(Self.tileShape)
        .glassEffect(.regular, in: Self.tileShape)
    }
}

/// Opens the classic menu. A plain hover-aware row rather than a `Button`,
/// whose style only exposes pressed state, not hover.
private struct MoreRow: View {
    let onShowClassicMenu: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            CalenbarBadge {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text("calenbar_panel_more".loco())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calenbarRowBubble(hovered: isHovered)
        .contentShape(Rectangle())
        .calenbarRowHover { isHovered = $0 }
        .onTapGesture(perform: onShowClassicMenu)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("calenbar_panel_more_accessibility_label".loco())
        .accessibilityHint("calenbar_panel_more_accessibility_hint".loco())
        .calenbarAccessibilityButton(onShowClassicMenu)
    }
}

/// Draws a panel row as a Control Center-style bubble: a faint chip that
/// brightens on hover. Its corners are concentric with the tile around it
/// (see `containerShape`), with a minimum radius for corners away from the
/// tile's own corners.
extension View {
    func calenbarRowBubble(hovered: Bool) -> some View {
        background(
            ConcentricRectangle(corners: .concentric(minimum: 10))
                .fill(Color.primary.opacity(hovered ? 0.16 : 0.06))
        )
    }
}

/// The panel's rows are tap-gesture views rather than `Button`s (a button
/// style can't see hover), so they tell VoiceOver they're buttons and what
/// pressing them does. Rows without an action stay plain elements.
extension View {
    func calenbarAccessibilityButton(_ action: (() -> Void)?) -> some View {
        accessibilityAddTraits(action != nil ? .isButton : [])
            .accessibilityAction { action?() }
    }
}

/// Reliable hover detection for the panel's rows. SwiftUI's `.onHover` ties
/// its tracking area to the key window, but this panel never becomes key (see
/// `CalenbarPanelController`), so it fires inconsistently. An `NSTrackingArea`
/// with `.activeAlways` works regardless.
extension View {
    func calenbarRowHover(
        pointingHand: Bool = true,
        _ onChange: @escaping (Bool) -> Void
    ) -> some View {
        overlay(CalenbarHoverTracker(pointingHand: pointingHand, onChange: onChange))
    }
}

private struct CalenbarHoverTracker: NSViewRepresentable {
    let pointingHand: Bool
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> CalenbarHoverTrackingView {
        let view = CalenbarHoverTrackingView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: CalenbarHoverTrackingView, context: Context) {
        view.showsPointingHand = pointingHand
        view.onChange = onChange
    }
}

final class CalenbarHoverTrackingView: NSView {
    var onChange: ((Bool) -> Void)?
    var showsPointingHand = true
    private(set) var isShowingPointingHand = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        onChange?(true)
        if showsPointingHand, !isShowingPointingHand {
            NSCursor.pointingHand.push()
            isShowingPointingHand = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        endHover()
    }

    // Closing the panel mid-hover never delivers mouseExited, so release the
    // cursor and hover state when the view leaves its window.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, isHovered { endHover() }
    }

    private func endHover() {
        isHovered = false
        onChange?(false)
        if isShowingPointingHand {
            NSCursor.pop()
            isShowingPointingHand = false
        }
    }

    // Only observes the pointer; clicks go to the SwiftUI row underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
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
