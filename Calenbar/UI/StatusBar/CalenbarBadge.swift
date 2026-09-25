//
//  CalenbarBadge.swift
//  Calenbar
//

import Defaults
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

/// Colors an event icon per the "Icon color" preference. The HIG allows
/// color on symbols, and keeps colored backgrounds for the one primary
/// action (Join), so badge circles stay neutral either way.
struct CalenbarIconColor: ViewModifier {
    @Default(.panelIconColor) private var iconColor

    func body(content: Content) -> some View {
        switch iconColor {
        case .monochrome: content.foregroundStyle(.primary)
        case .accent: content.foregroundStyle(.tint)
        }
    }
}

/// An event's badge: a meeting service's logo, or a symbol (video for a
/// meeting happening now, calendar otherwise).
struct CalenbarEventBadge: View {
    let badge: CalenbarRowBadge
    var size: CGFloat = 26

    var body: some View {
        CalenbarBadge(size: size) {
            switch badge {
            case .live(let hasMeeting):
                symbol(hasMeeting ? "video.fill" : "calendar")
            case .service(let service):
                Image(nsImage: getIconForMeetingService(service))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.57, height: size * 0.57)
            case .plain:
                symbol("calendar")
            }
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.46, weight: .semibold))
            .modifier(CalenbarIconColor())
    }
}
