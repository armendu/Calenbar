//
//  CalenbarPanelController.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// Accepts the first click. The panel never becomes key, so without this the
/// first click on Join or a row would only activate the window.
private final class CalenbarPanelHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Shows the Liquid Glass panel in a non-activating `NSPanel` under the
/// status item on left-click. Right-click still joins the next meeting, and
/// the classic menu stays reachable through the panel's "More…" row.
@MainActor
final class CalenbarPanelController: NSObject {
    private var panel: NSPanel?
    private var hostingView: CalenbarPanelHostingView<CalenbarGlassPanelView>?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    var isVisible: Bool { panel != nil }

    /// Shows the panel, or hides it if it's already open (like clicking a
    /// menu's title again).
    func toggle(
        near button: NSStatusBarButton,
        viewModel: CalenbarPanelViewModel,
        onJoin: @escaping () -> Void,
        onSelectAgendaRow: @escaping (CalenbarAgendaRow) -> Void,
        onShowClassicMenu: @escaping () -> Void
    ) {
        if panel != nil {
            dismiss()
            return
        }
        show(
            near: button,
            viewModel: viewModel,
            onJoin: onJoin,
            onSelectAgendaRow: onSelectAgendaRow,
            onShowClassicMenu: onShowClassicMenu
        )
    }

    /// Updates the open panel's content in place, so its countdown keeps ticking.
    func refresh(viewModel: CalenbarPanelViewModel) {
        guard let hostingView else { return }
        hostingView.rootView = CalenbarGlassPanelView(
            viewModel: viewModel,
            onJoin: hostingView.rootView.onJoin,
            onSelectAgendaRow: hostingView.rootView.onSelectAgendaRow,
            onShowClassicMenu: hostingView.rootView.onShowClassicMenu
        )
    }

    private func show(
        near button: NSStatusBarButton,
        viewModel: CalenbarPanelViewModel,
        onJoin: @escaping () -> Void,
        onSelectAgendaRow: @escaping (CalenbarAgendaRow) -> Void,
        onShowClassicMenu: @escaping () -> Void
    ) {
        let panelView = CalenbarGlassPanelView(
            viewModel: viewModel,
            onJoin: { [weak self] in onJoin(); self?.dismiss() },
            onSelectAgendaRow: { [weak self] row in onSelectAgendaRow(row); self?.dismiss() },
            onShowClassicMenu: { [weak self] in self?.dismissThenPerform(onShowClassicMenu) }
        )
        let hosting = CalenbarPanelHostingView(rootView: panelView)
        // The width is fixed; only the height depends on the content.
        let targetWidth = CalenbarGlassPanelView.width
        hosting.frame = NSRect(x: 0, y: 0, width: targetWidth, height: 1)
        hosting.layoutSubtreeIfNeeded()
        let fitSize = NSSize(width: targetWidth, height: max(hosting.fittingSize.height, 1))
        hosting.frame = NSRect(origin: .zero, size: fitSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: fitSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        // Floats above normal windows without stealing focus from the front app.
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        position(panel, near: button, size: fitSize)

        panel.orderFrontRegardless()
        self.panel = panel
        self.hostingView = hosting
        installDismissalMonitors(ignoring: button)
    }

    private func position(_ panel: NSPanel, near button: NSStatusBarButton, size: NSSize) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen ?? NSScreen.main else {
            panel.center()
            return
        }
        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.frame)
        var origin = NSPoint(
            x: buttonFrameOnScreen.midX - size.width / 2,
            y: buttonFrameOnScreen.minY - size.height - 4
        )
        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        // Keep a very tall panel (a packed day) on screen at both edges.
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        removeDismissalMonitors()
        panel?.orderOut(nil)
        // Detach the content so hovered rows get viewWillMove(toWindow: nil)
        // and release their cursor; releasing the panel alone doesn't.
        panel?.contentView = nil
        panel = nil
        hostingView = nil
    }

    /// Closes the panel before running `action`. Opening the classic menu
    /// blocks while it tracks, so closing afterwards would leave the panel and
    /// the menu on screen together.
    func dismissThenPerform(_ action: () -> Void) {
        dismiss()
        action()
    }

    /// Closes the panel on an outside click, Esc, app deactivation or display
    /// sleep. Clicks on the status item itself are left to `toggle()`.
    private func installDismissalMonitors(ignoring button: NSStatusBarButton) {
        // Esc arrives at the frontmost app (the panel is never key), so it
        // needs the global monitor. macOS only delivers global key events with
        // Input Monitoring permission, which isn't requested; without it Esc
        // does nothing and the other dismissal paths still work.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self, weak button] event in
            guard let self else { return }
            if event.type == .keyDown {
                if event.keyCode == kVK_Escape { self.dismiss() }
                return
            }
            guard let button, let buttonWindow = button.window else { return }
            let clickedStatusItemButton = buttonWindow.windowNumber == event.windowNumber
            guard !clickedStatusItemButton else { return }
            self.dismiss()
        }
        // Global monitors never see this app's own events; catch Esc here too.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == kVK_Escape {
                self.dismiss()
                return nil
            }
            return event
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(dismissFromNotification),
            name: NSApplication.didResignActiveNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(dismissFromNotification),
            name: NSWorkspace.screensDidSleepNotification, object: nil
        )
        // Screen lock is handled by AppDelegate's existing lock observer.
    }

    private func removeDismissalMonitors() {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        globalClickMonitor = nil
        localKeyMonitor = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func dismissFromNotification() {
        dismiss()
    }
}

/// Carbon's `kVK_Escape`, declared here to avoid importing Carbon.
private let kVK_Escape: UInt16 = 53
