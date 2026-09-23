//
//  MeetingSummaryView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

// `MeetingSummaryPresentation` lives in `CalenbarPanelViewModel.swift` (pure,
// AppKit-free) so it can be produced by logic that doesn't depend on AppKit
// or SwiftUI. This file just renders it.

struct MeetingSummaryView: View {
    let presentation: MeetingSummaryPresentation
    let providerIcon: NSImage
    var onJoin: (() -> Void)?

    @State private var isHovered = false

    static let preferredWidth: CGFloat = 320
    static let preferredHeight: CGFloat = 66

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.sectionTitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 7) {
                    Image(nsImage: providerIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text(presentation.eventTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(presentation.metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if onJoin != nil {
                Spacer(minLength: 8)
                Text("notifications_meetingbar_join_event_action".loco())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor))
                    .opacity(isHovered ? 1.0 : 0.9)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // A capped maxWidth, not .infinity: this view is the root view of an
        // NSMenuItem custom view (see MenuBuilder.makeMeetingSummaryItem),
        // and NSMenu consults NSHostingView.fittingSize to size the whole
        // menu. An unbounded .infinity here reports back a huge "ideal"
        // width (the same NSHostingView.fittingSize unreliability already
        // found for the glass panel in CalenbarPanelController), stretching
        // the entire classic menu far past its intended 320pt. Deliberately
        // NOT a rigid minWidth+maxWidth pin, though: this view is reused
        // inside the glass panel's summary tile (CalenbarGlassPanelView),
        // which only has ~312pt available after its own padding — a rigid
        // 320pt there overflows the tile's rounded shape on one side. A
        // bare maxWidth caps the runaway-ideal-size case while still
        // shrinking to fit whatever narrower width it's actually given.
        .frame(
            maxWidth: Self.preferredWidth,
            minHeight: Self.preferredHeight,
            alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered && onJoin != nil ? Color.primary.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            guard onJoin != nil else { return }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture { onJoin?() }
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
        providerIcon: getIconForMeetingService(.zoom),
        onJoin: {}
    )
}
