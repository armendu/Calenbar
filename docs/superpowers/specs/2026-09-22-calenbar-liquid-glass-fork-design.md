# Calenbar: a Liquid Glass fork of MeetingBar

Date: 2026-09-22
Status: Approved for planning

## Summary

Calenbar is a UI/UX-focused fork of [leits/MeetingBar](https://github.com/leits/MeetingBar) (Apache 2.0), an existing open-source macOS menu bar app that shows the current/next Calendar.app meeting and lets you join it in one click. MeetingBar already does everything the feature requirements call for (EventKit integration, meeting-link detection for 50+ services, notifications, Homebrew Cask distribution). The gap is visual: its dropdown is a stock `NSMenu`. Calenbar's job is to replace that with a custom Liquid Glass panel — the translucent material macOS 26 uses in Control Center and other system surfaces — while leaving the underlying calendar/meeting logic untouched.

## Goals

- Keep all of MeetingBar's existing functionality (join-link detection, notifications, service icons, AppleScript hooks, preferences, onboarding).
- Replace the native `NSMenu` dropdown with a custom borderless panel using macOS 26 Liquid Glass materials (`.glassEffect()` / `GlassEffectContainer`), while reproducing the baseline keyboard/VoiceOver interaction `NSMenu` currently gives for free.
- Status bar shows an icon + short countdown (e.g. an icon plus "4m"). Confirmed this is achievable via an existing combination of MeetingBar settings — `EventTitleFormat.none` (empty title) + `EventTimeFormat.show` (renders the countdown) + an icon format that shows a real icon (`.eventtype` or `.calendar`) — not a new display mode; see "What changes" below for the one small renderer bug this combination exposes.
- Ship installable via a personal Homebrew tap: `brew install --cask calenbar`.
- Preserve git history and comply with the Apache 2.0 license as a proper GitHub fork.
- Minimum deployment target is **macOS 26 (Tahoe)**, up from MeetingBar's current `.macOS(.v12)` — required by the Liquid Glass APIs. This is a resolved decision, not deferred: Calenbar is a personal tool for current-macOS use, so cutting off pre-26 systems is acceptable. `Package.swift`, the Xcode project's `MACOSX_DEPLOYMENT_TARGET`, the Cask's `depends_on macos:`, and the README must all state this.

## Non-goals (v1)

- Redesigning Preferences, Onboarding, or notification UI.
- Code signing / notarization (ship unsigned; add later without restructuring).
- Upstreaming changes back to MeetingBar.
- Mac App Store distribution.
- New app icon/logo design — ship with a placeholder/neutral icon for v1 rather than MeetingBar's original branding (Apache 2.0 covers the code, not MeetingBar's trademark/branding, so keeping their icon on a renamed app is out regardless; designing a real replacement icon is separate follow-up work).
- Full accessibility parity beyond the baseline described in "Accessibility" — this is a personal tool, not a general-audience release.

## Repo strategy

Create a real GitHub fork (not a manual clone+push) so the fork relationship, network graph, and full commit history are preserved:

1. `gh repo fork leits/MeetingBar --clone=false` → creates `armendu/MeetingBar`.
2. `gh repo rename Calenbar -R armendu/MeetingBar` → renames to `armendu/Calenbar`; GitHub tracks forks by internal repo ID, so the fork badge/graph survives the rename.
3. Clone `armendu/Calenbar` into this directory as `origin`; add `leits/MeetingBar` as `upstream` remote for pulling future upstream fixes.

License compliance (Apache 2.0 §4): keep `LICENSE` unmodified; keep existing per-file copyright headers in place — including in files we modify (e.g. `StatusBarItemController.swift`, `MenuBuilder.swift`, `StatusBarPresentation.swift`), per §4(c), rather than only in files left untouched; add a short "Changes from upstream" note (README section or `CHANGES.md`) listing modified files, since §4(b) requires stating that files were modified. Confirmed upstream `leits/MeetingBar` ships no separate `NOTICE` file, so §4(d) doesn't apply.

## Architecture

### What stays as-is

Everything outside status-bar rendering and title formatting: `Calendar/` (EventKit sync, `MBEvent`), `Meetings/` (link detection, `MeetingProvider`), `Notifications/`, `Preferences/`, `Onboarding/`, `Settings/`, `App/`. This code is already covered by `MeetingBarLogicTests` and is exactly what the feature requirements need — no reason to touch it.

### What changes

**1. Status bar title/icon format.** Traced the render path: with `titleFormat: .none` (empty title) + `timeDisplay: .show`, `StatusBarPresentationPolicy`'s `titleLayout` returns `.inline(showTime: true)`, and `StatusBarTitleRenderer.attributedTitle` (`StatusBarItemController.swift:511-515`) renders `presentation.title + " " + presentation.time` — with an empty title, that's just the countdown, next to whatever icon `iconFormat: .eventtype` or `.calendar` selects. So "icon + short countdown" is **already reachable with existing settings, no new enum case needed** — except that concatenation always prepends a space (`"" + " " + "4m"` → `" 4m"`), a small cosmetic bug worth fixing (skip the separator when `presentation.title` is empty) since it's now a default-path combination for Calenbar rather than a rarely-used corner case. `StatusBarPresentation.swift`/`StatusBarTitlePolicy` stay conceptually untouched (no new format), and `StatusBarItemController.swift`'s renderer gets a one-line fix plus Calenbar's shipped Defaults changing to this combination.

**2. The dropdown itself.** MeetingBar's dropdown is a real `NSMenu` built by `MenuBuilder` and shown from `StatusBarItemController` (`statusItem.button` → `NSMenu.popUp`). `NSMenu` is OS-owned chrome: individual menu items can host SwiftUI content (MeetingBar already does this for the summary row via `MeetingSummaryView`), but the menu surface itself cannot take a Liquid Glass material — the system draws it. Getting a genuine glass look requires replacing the menu with a **custom borderless `NSPanel`** anchored under the status item, hosting a SwiftUI view tree built with `.glassEffect()`.

- `StatusBarItemController` keeps owning the `NSStatusItem` for the icon + short countdown text. On click, it shows/hides the custom panel instead of calling `NSMenu.popUp`.
- `MenuBuilder`'s data-producing logic (`buildTopSection`, `meetingSummaryPresentation`, event list assembly) is extracted into a plain, testable view-model (`CalenbarPanelViewModel`) instead of `[NSMenuItem]`. New SwiftUI views (glass panel container, event rows, join button) consume that same view-model — the underlying event/settings data doesn't change, only what renders it.
- `CalenbarPanelViewModel` is **observable and live-updating** while the panel is open — it subscribes to the same refresh timer/Combine pipeline that already drives the `NSStatusItem` title updates (see `StatusBarItemController`'s existing update cycle), so a countdown visible in the open panel ticks from "4m" to "3m" without the user closing and reopening it. It is not a one-shot snapshot.
- Preferences window, onboarding, and notification banners stay native as they are today; out of scope per the goals above.

### Panel mechanics

The custom `NSPanel` must reproduce the behaviors `NSMenu` currently provides for free:

- **Window setup:** `.nonactivatingPanel` style mask + a status-bar-appropriate window level, so opening the panel never steals focus/activation from the frontmost app (a hard requirement for a menu-bar utility).
- **Dismissal triggers:** click outside the panel (global event monitor), Esc key, re-clicking the status item, the app resigning key status, and system screen lock/sleep (`NSWorkspace` notifications). Pressing "Join" dismisses the panel after opening the link, mirroring `NSMenu`'s dismiss-on-item-click behavior.
- **Positioning:** anchored under the status item, clamped to stay on-screen near display edges or a crowded/notched menu bar.

### Accessibility

Replacing `NSMenu` means deliberately rebuilding what it gave away for free:

- Keyboard: arrow keys move focus between rows, Return activates the focused row's default action (open event / join), Esc dismisses — matching baseline `NSMenu` keyboard use.
- VoiceOver: every interactive SwiftUI element (event rows, Join button, section headers) gets an explicit `accessibilityLabel`/`accessibilityHint`; the panel gets `accessibilityAddedSubrole` / behaves as a coherent focus region rather than a floating window VoiceOver can't parse.
- Reduce Transparency / Increase Contrast: SwiftUI materials generally adapt to these automatically, but this must be manually verified (System Settings → Accessibility) during implementation rather than assumed — glass is exactly the kind of effect these settings target.

This is scoped to baseline parity (per the Non-goals note above), not a full accessibility audit.

### Data flow

`AppModel`/`AppState` (unchanged) → `StatusBarMenuState` snapshot (unchanged) → `CalenbarPanelViewModel` (observable; replaces `MenuBuilder`'s `[NSMenuItem]` output with live view data) → SwiftUI glass views, rendered inside an `NSHostingView` embedded in the custom `NSPanel`.

## Distribution

- GitHub Actions builds and zips the `.app` on tag push (no signing/notarization for v1). Building against the macOS 26 SDK requires a runner image with a matching Xcode version — pin the workflow to a specific verified image (e.g. a dated `macos-*` GitHub-hosted runner or Xcode version) rather than `macos-latest`, confirmed against current `actions/runner-images` availability at implementation time, since hosted-runner SDK support can lag a new macOS release.
- New repo `armendu/homebrew-calenbar` holds a single Cask formula pointing at the release asset, with `depends_on macos: ">= :tahoe"` (or the exact Cask DSL equivalent for macOS 26).
- Cask `caveats` block tells users to right-click → Open on first launch (standard unsigned-cask pattern) since it isn't notarized.
- Install: `brew tap armendu/calenbar && brew install --cask calenbar`.

## Testing

- Keep `MeetingBarLogicTests` green — it covers the untouched policy logic. Add a regression test for the `StatusBarTitleRenderer.attributedTitle` leading-space fix (empty title + `showTime: true` → no leading space), following the existing `StatusBarTitlePolicyTests`/`StatusBarIconPolicyTests` pattern.
- Add unit tests for `CalenbarPanelViewModel`'s data-producing logic, mirroring the existing pure-policy test pattern rather than leaving the extraction untested.
- Add SwiftUI `#Preview` blocks for the new glass panel and its subviews (matches existing codebase convention, e.g. `MeetingSummaryView.swift`).
- Glass rendering itself isn't meaningfully unit-testable; verify visually via manual run + screenshots during implementation, including a manual check with Reduce Transparency enabled.

## Risks

- Unsigned distribution means every update still trips Gatekeeper on first launch until notarization is added later.
- Hosted CI runner SDK/Xcode availability for macOS 26 is unverified until the build workflow is actually implemented (see Distribution).
