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
/// `NSHostingView` subclass that accepts the first mouse click. The panel
/// deliberately never becomes key (see `show`), and AppKit's default
/// `acceptsFirstMouse(for:)` is `false` — without this override, every click
/// inside a permanently-non-key panel (Join, an agenda row, "More…") would
/// be swallowed just to activate the panel's window, requiring a second
/// click to actually register. This is the standard fix for this well-known
/// AppKit gotcha with custom status-item popups.
private final class CalenbarPanelHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class CalenbarPanelController: NSObject {
    private var panel: NSPanel?
    private var hostingView: CalenbarPanelHostingView<CalenbarGlassPanelView>?
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
            onShowClassicMenu: { [weak self] in self?.dismissThenPerform(onShowClassicMenu) }
        )
        let hosting = CalenbarPanelHostingView(rootView: panelView)
        // Give the hosting view a concrete starting frame before asking for
        // fittingSize. A standalone (non-windowed) compile-time check during
        // development showed this producing a correct, non-zero size for
        // this panel's fixed-width/natural-height layout even
        // pre-attachment to a window — but that check never ran inside a
        // real app/window server, so treat this as "expected to work," not
        // confirmed: verify fittingSize's actual runtime value the first
        // time this runs on a device, before trusting it further.
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

    /// Dismisses the panel, then invokes `action` — order matters. Used for
    /// `onShowClassicMenu`: `openMenu()`'s `performClick(nil)` blocks for as
    /// long as the classic NSMenu is tracking, so `action` must never
    /// observe the glass panel still on screen (previously it did, since
    /// dismiss ran *after* the callback — two floating panels stacked on
    /// screen for the whole time the classic menu was open, which read as
    /// broken and put "Quit Calenbar" right where someone reaching to
    /// dismiss the confusion would click). `internal`, not `private`, so
    /// this ordering guarantee is directly unit-testable without needing a
    /// live NSPanel/NSStatusBarButton.
    func dismissThenPerform(_ action: () -> Void) {
        dismiss()
        action()
    }

    /// `ignoring button`: `toggle()` already handles "click the status item
    /// again to close," so this monitor only needs to handle *outside*
    /// clicks. Global monitors only observe events sent to other
    /// applications (per Apple's docs), so a click on our own status item
    /// button likely never reaches this handler in the first place — the
    /// `clickedStatusItemButton` guard below may be belt-and-suspenders
    /// rather than load-bearing; kept for now, worth re-checking once this
    /// can be click-tested on a device.
    private func installDismissalMonitors(ignoring button: NSStatusBarButton) {
        // Esc is handled on the *global* monitor, not a local one: this
        // panel deliberately never becomes key (see `show`), so the real key
        // window stays whatever other app's window was key before — a local
        // monitor (events sent to this app) wouldn't see an Esc press
        // delivered there. A global monitor (events sent to other apps) is
        // exactly why click-outside detection below already needed one; Esc
        // rides along on the same monitor for the same reason.
        //
        // CAVEAT, unresolved — needs a real device to confirm: global
        // *keyboard* monitors (unlike mouse ones) require the user to have
        // granted Input Monitoring (System Settings → Privacy & Security).
        // Nothing here requests that permission, so this Esc path likely
        // silently no-ops on a typical first run. The other four dismissal
        // triggers don't depend on it and stay reliable regardless.
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
        // Defensive fallback for the (normally unreachable, since the panel
        // isn't key) case where Esc somehow lands locally — harmless to
        // keep, global monitors can't cover events sent to this app itself.
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
        // Screen *lock* is a distinct event from sleep, and is NOT handled
        // here: the app already listens for it once, in
        // LifecycleObserver/AppDelegate ("com.apple.screenIsLocked",
        // forwarded as onScreenLocked), which now also calls
        // calenbarPanelController.dismiss(). A second independent listener
        // for the same fragile, string-keyed, undocumented system
        // notification here would risk silently diverging from that one if
        // either copy ever changed — better to have exactly one owner of it.
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

/// `kVK_Escape` isn't exposed by a public AppKit/Carbon import in this
/// target (only available via the deprecated Carbon HIToolbox headers) —
/// its value (53) is a stable, documented virtual keycode constant, so it's
/// declared directly rather than importing Carbon for one constant.
private let kVK_Escape: UInt16 = 53
