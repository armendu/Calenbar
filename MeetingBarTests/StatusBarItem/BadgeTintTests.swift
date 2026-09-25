//
//  BadgeTintTests.swift
//  MeetingBarTests
//

import AppKit
import Defaults
import SwiftUI
import XCTest

@testable import Calenbar

/// Badge symbols sit on a neutral circle and are monochrome, or the system
/// tint when "Icon color" is set to the accent color.
@MainActor
final class BadgeTintTests: BaseTestCase {
    private func pixels(of view: some View) throws -> [NSColor] {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        var colors: [NSColor] = []
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.9 {
                    colors.append(color)
                }
            }
        }
        return colors
    }

    /// The system tint as this renderer draws it.
    private lazy var tint: NSColor? = try? pixels(of: AnyView(Rectangle().fill(.tint).frame(width: 4, height: 4))).first

    private func isTint(_ color: NSColor) -> Bool {
        guard let tint else { return false }
        return abs(color.redComponent - tint.redComponent) < 0.12
            && abs(color.greenComponent - tint.greenComponent) < 0.12
            && abs(color.blueComponent - tint.blueComponent) < 0.12
    }

    private func isWhite(_ color: NSColor) -> Bool {
        color.redComponent > 0.95 && color.greenComponent > 0.95 && color.blueComponent > 0.95
    }

    private func assertSymbol(
        of badge: CalenbarRowBadge, isTinted tinted: Bool,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let colors = try pixels(of: CalenbarEventBadge(badge: badge))

        XCTAssertEqual(colors.contains(where: isTint), tinted, "symbol tint", file: file, line: line)
        // A white symbol covers a small part of the badge; a white circle most of it.
        let whiteShare = Double(colors.filter(isWhite).count) / Double(max(colors.count, 1))
        XCTAssertLessThan(whiteShare, 0.5, "circle shouldn't be white", file: file, line: line)
    }

    func test_iconsAreMonochromeByDefault() throws {
        XCTAssertEqual(Defaults[.panelIconColor], .monochrome)
        try assertSymbol(of: .plain, isTinted: false)
        try assertSymbol(of: .live(hasMeeting: true), isTinted: false)
    }

    func test_accentColorSettingTintsEveryEventIcon() throws {
        Defaults[.panelIconColor] = .accent

        try assertSymbol(of: .plain, isTinted: true)
        try assertSymbol(of: .live(hasMeeting: true), isTinted: true)
        try assertSymbol(of: .live(hasMeeting: false), isTinted: true)
    }
}
