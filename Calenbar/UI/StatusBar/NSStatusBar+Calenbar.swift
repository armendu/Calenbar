//
//  NSStatusBar+Calenbar.swift
//  Calenbar
//

import AppKit

extension NSStatusBar {
    static let testHostAutosaveNamePrefix = "dev.armendu.Calenbar.tests.status-item"

    /// Creates a variable-length status item.
    ///
    /// AppKit keeps each item's menu bar position in `.standard` under
    /// `NSStatusItem Preferred Position <autosaveName>` and deletes that key when
    /// the item is removed. The first item's default name, `Item-0`, is the one
    /// the user's running Calenbar uses, so under XCTest every item gets its own
    /// name to keep tests from wiping the real menu bar position.
    func makeCalenbarStatusItem(
        hostingTests: Bool = TestHostDetection.isHostingTests()
    ) -> NSStatusItem {
        let item = statusItem(withLength: NSStatusItem.variableLength)
        if hostingTests {
            item.autosaveName = "\(Self.testHostAutosaveNamePrefix)-\(UUID().uuidString)"
        }
        return item
    }
}
