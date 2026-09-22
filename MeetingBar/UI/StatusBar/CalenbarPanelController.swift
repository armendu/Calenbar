//
//  CalenbarPanelController.swift
//  MeetingBar
//

import AppKit
import SwiftUI

/// Hosts the Liquid Glass panel (`CalenbarGlassPanelView`) in a custom,
/// non-activating `NSPanel` anchored under the status item, shown on
/// left-click in place of `StatusBarItemController.openMenu()`.
///
/// Right-click's existing behavior (`joinNextMeeting()`, an instant-join
/// shortcut — NOT a menu trigger, confirmed by reading the current
/// `statusMenuBarAction`) is untouched. The classic `NSMenu`
/// (`StatusBarItemController.openMenu()`) is still reachable from inside the
/// panel via its "More…" row (see `CalenbarGlassPanelView.onShowClassicMenu`)
/// rather than being bound to right-click, so every existing feature that
/// only lives in the classic menu stays reachable — right-click's shortcut
/// just isn't sacrificed to make room for it.
@MainActor
final class CalenbarPanelController: NSObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<CalenbarGlassPanelView>?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    var isVisible: Bool { panel != nil }

    /// Shows the panel if hidden, hides it if already showing (mirrors
    /// `NSMenu.popUp`'s toggle-on-reclick behavior, which `openMenu()`
    /// previously got for free from AppKit).
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

    /// Rebuilds the panel's content in place while it's open, without
    /// changing its position/visibility — called on every tick of the same
    /// refresh pipeline that drives `StatusBarItemController.updateTitle()`,
    /// so a countdown visible in the open panel ticks down live instead of
    /// freezing at whatever it read when the panel opened.
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
            onShowClassicMenu: { [weak self] in onShowClassicMenu(); self?.dismiss() }
        )
        let hosting = NSHostingView(rootView: panelView)
        // Give the hosting view a concrete starting frame before asking for
        // fittingSize — verified empirically (not assumed) that this
        // produces a correct, non-zero size for this panel's fixed-width /
        // natural-height layout even pre-attachment to a window, but we
        // still size the frame explicitly first as defense in depth: SwiftUI
        // layout is generally undefined before a view has an established
        // frame to lay out within.
        hosting.frame = NSRect(x: 0, y: 0, width: CalenbarGlassPanelView.width, height: 1)
        let fitSize = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: fitSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: fitSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        // .statusBar level + .nonactivatingPanel keeps this above normal
        // windows without activating the app or stealing key focus from
        // whatever app was frontmost when the status item was clicked.
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
        // Clamp both edges, not just the bottom: today's agenda is bounded
        // to one day's events so this shouldn't trigger in practice, but an
        // unusually tall panel (e.g. a day packed with meetings) should
        // still be pulled down to fit on-screen rather than clipped off the
        // top, the same way the bottom edge is already handled.
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        removeDismissalMonitors()
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    /// `ignoring button`: the global monitor fires on mouse-down anywhere,
    /// including on the status item button itself — without excluding it,
    /// clicking the button to close an open panel would both (a) dismiss via
    /// this monitor and (b) immediately reopen via
    /// `StatusBarItemController.statusMenuBarAction`'s own click handling,
    /// which would look like the panel never closed. `toggle(...)` already
    /// handles the "click while open → close" case itself, so this monitor
    /// only needs to handle *outside* clicks; a click landing back on the
    /// status item is deliberately left to `toggle`, not double-handled here.
    private func installDismissalMonitors(ignoring button: NSStatusBarButton) {
        // .keyDown is included here (not just click events) because the
        // panel deliberately never becomes key (.nonactivatingPanel +
        // orderFrontRegardless(), not makeKeyAndOrderFront — see `show`).
        // With the panel non-key, the actual key window stays whatever other
        // app's window was key before the status item was clicked, so an Esc
        // press is delivered to THAT app, not to us — a *local* monitor
        // (which only observes events sent to this app) would never see it.
        // A *global* monitor observes events delivered to other
        // applications, which is exactly why the existing click-outside
        // handling below already has to use one; the same reasoning applies
        // to Esc, so both live on one global monitor rather than pairing a
        // global click monitor with a local key monitor that would rarely
        // fire in practice.
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
        // Defensive fallback: a global monitor cannot observe events sent to
        // this app itself, so this covers the (normally unreachable, since
        // the panel isn't key) case where Esc somehow does land locally —
        // harmless to keep, and swallows the event when it does apply.
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
        // Screen *lock* (e.g. Cmd+Ctrl+Q) is a distinct event from sleep,
        // delivered on the distributed notification center rather than
        // NSWorkspace's — without this, locking the screen while the panel
        // is open would leave it visibly on-screen over the lock screen.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(dismissFromNotification),
            name: Notification.Name("com.apple.screenIsLocked"), object: nil
        )
    }

    private func removeDismissalMonitors() {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        globalClickMonitor = nil
        localKeyMonitor = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func dismissFromNotification() {
        dismiss()
    }
}

/// `kVK_Escape` isn't exposed by a public AppKit/Carbon import in this
/// target (only available via the deprecated Carbon HIToolbox headers) —
/// its value (53) is a stable, documented virtual keycode constant, so it's
/// declared directly rather than importing Carbon for one constant.
private let kVK_Escape: UInt16 = 53
