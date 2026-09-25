//
//  CalenbarBadge.swift
//  Calenbar
//

import SwiftUI

/// The circular badge at the start of each panel row, like the icon circles
/// on Control Center's controls.
struct CalenbarBadge<Content: View>: View {
    var size: CGFloat = 26
    var fill: Color = .primary.opacity(0.12)
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle().fill(fill)
            content
        }
        .frame(width: size, height: size)
    }
}

/// An event's badge: accent for a meeting happening now, the meeting
/// service's logo on white, or a plain calendar symbol.
struct CalenbarEventBadge: View {
    let badge: CalenbarRowBadge
    var size: CGFloat = 26

    var body: some View {
        switch badge {
        case .live(let hasMeeting):
            CalenbarBadge(size: size, fill: .accentColor) {
                symbol(hasMeeting ? "video.fill" : "calendar", color: .white)
            }
        case .service(let service):
            CalenbarBadge(size: size, fill: .white) {
                Image(nsImage: getIconForMeetingService(service))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.57, height: size * 0.57)
            }
        case .plain:
            CalenbarBadge(size: size) {
                symbol("calendar", color: .primary)
            }
        }
    }

    private func symbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(color)
    }
}
