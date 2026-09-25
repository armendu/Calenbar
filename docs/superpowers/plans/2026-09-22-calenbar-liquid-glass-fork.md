# Calenbar Liquid Glass Fork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork `leits/MeetingBar` into `armendu/Calenbar`, replace its native `NSMenu` dropdown with a custom Liquid Glass panel for the primary "next meeting" flow, and ship it via a personal Homebrew tap — while keeping every existing MeetingBar feature reachable.

**Architecture:** Two build phases. Phase 1 (Tasks 1-3) touches only the pure-Swift `MeetingBarLogic` SPM package and needs no Xcode — verified with `swift build`/`swift test` using Command Line Tools alone. Phase 2 (Tasks 4-13) touches the AppKit app target (asset catalogs, `.xcodeproj`, code signing) and **requires full Xcode 26 installed** — Phase 2 tasks are blocked until that's done. Within Phase 2, the existing `NSMenu` stays wired to right-click as a "classic menu" fallback with 100% of current functionality untouched; the new Liquid Glass `NSPanel` becomes the left-click primary surface for the high-frequency flow (see "Scope note" below).

**Tech Stack:** Swift 6, SwiftUI (`.glassEffect()`, `GlassEffectContainer` — macOS 26 SDK), AppKit (`NSStatusItem`, `NSPanel`, `NSHostingView`), Combine, `Defaults`, XCTest / `swift test`, GitHub Actions, Homebrew Cask.

---

## Scope note: primary vs. classic menu

`MenuBuilder.swift` is 1284 lines covering far more than the next-meeting summary — bookmarks, a multi-day date section, an attendees submenu, an alternate-meeting-links submenu, a preferences section, and detailed per-event appearance rules (past/running/upcoming, pending/tentative styling). Reproducing all of that in a hand-rolled SwiftUI glass panel in one pass is its own multi-week project and isn't what "focus on UI/UX" was meant to trade off against.

This plan instead keeps **both** surfaces:
- **Right-click (or the existing keyboard shortcut) → the untouched, existing `NSMenu`.** Every current feature stays reachable exactly as it is today. Nothing is removed.
- **Left-click → the new Liquid Glass `NSPanel`,** covering the primary flow: current/next meeting summary, Join button, and the today/tomorrow event list (title, time, tap-to-open) — i.e. `buildTopSection()` / `meetingSummaryPresentation()` / the basic event rows from `buildDateSection()`, re-rendered in SwiftUI.

If this splits further than you want (e.g. you'd rather the glass panel fully replace the classic menu on day one), say so before starting Task 7 — it's a cheap change now and an expensive one later.

This is a real deviation from the approved spec, which describes the panel replacing `NSMenu.popUp` outright with no mention of a classic-menu fallback. Once confirmed, update the spec's Architecture/Goals sections to match before Task 7 starts (a quick edit + commit to `docs/superpowers/specs/2026-09-22-calenbar-liquid-glass-fork-design.md`), so the spec and the shipped behavior don't permanently disagree with each other.

---

## Phase 1 — No Xcode required

### Task 1: Fork the repo and set up the local project

**Files:**
- Modify: `/Users/armend/Developer/calenbar-macos/` (this directory's git remotes and working tree)

This replaces the standalone git repo currently holding only `docs/`, with a real GitHub fork of MeetingBar carrying the docs forward as a new commit on top of upstream history.

- [ ] **Step 1: Create the GitHub fork**

```bash
gh repo fork leits/MeetingBar --clone=false
gh repo rename Calenbar -R armendu/MeetingBar
```
Expected: `gh` reports `armendu/Calenbar` created and renamed. Verify with `gh repo view armendu/Calenbar --json parent` showing `leits/MeetingBar` as parent (confirms fork relationship survived the rename).

- [ ] **Step 2: Clone the fork into the scratchpad and copy docs over**

Use the session scratchpad, not `/tmp` (not guaranteed to survive a reboot). Check the fork's actual default branch rather than assuming — GitHub forks inherit the parent's default branch name, and `leits/MeetingBar`'s default branch is `master`, not `main`.

```bash
FORK_CLONE_DIR="$CLAUDE_SCRATCHPAD_DIR/calenbar-fork-clone"   # substitute the actual scratchpad path
git clone https://github.com/armendu/Calenbar.git "$FORK_CLONE_DIR"
cd "$FORK_CLONE_DIR"
git branch --show-current   # confirm this prints the fork's actual default branch (expect "master") — use that name in Step 2's push below, not a hardcoded "main"
cp -R /Users/armend/Developer/calenbar-macos/docs "$FORK_CLONE_DIR/docs"
git add docs
git commit -m "Add Calenbar project docs (design spec + implementation plan)"
git remote add upstream https://github.com/leits/MeetingBar.git
git push origin HEAD   # pushes to whatever branch is currently checked out, avoiding a hardcoded branch-name mismatch
```

- [ ] **Step 3: Back up (don't delete) the current working directory's git history, then install the fork's**

The current repo in `/Users/armend/Developer/calenbar-macos` holds real, unpushed history (the spec/plan authoring commits) with no remote — verify this before touching anything, and never `rm -rf` a `.git` directory that hasn't been confirmed recoverable elsewhere.

```bash
cd /Users/armend/Developer/calenbar-macos
git status                       # must be clean (no uncommitted changes) before proceeding
git remote -v                    # expect no output — confirms this history isn't pushed anywhere else
git log --oneline                # sanity-check: this is the docs-only spec/plan history, nothing unexpected

mv .git .git.pre-fork-backup     # rename aside, do NOT delete — this is the only copy of this history
mv "$FORK_CLONE_DIR/.git" .git
git reset --hard HEAD
```
Expected: `git status` is clean, `git log --oneline -5` shows the new docs commit on top of MeetingBar's history, `git remote -v` shows `origin` → `armendu/Calenbar` and `upstream` → `leits/MeetingBar`, and `git log --oneline | grep -c "Correct status-bar countdown"` (or another commit message unique to the docs-only history) confirms the docs commit landed correctly.

- [ ] **Step 4: Verify the logic package still builds from the new location**

```bash
cd /Users/armend/Developer/calenbar-macos && swift build
```
Expected: `Build complete!` (same as verified during planning research).

- [ ] **Step 5: Only after Step 4 passes, remove the backup**

```bash
rm -rf /Users/armend/Developer/calenbar-macos/.git.pre-fork-backup
rm -rf "$FORK_CLONE_DIR"
```
If anything in Steps 3-4 looked wrong, stop here instead and restore with `rm -rf .git && mv .git.pre-fork-backup .git` rather than deleting the backup.

- [ ] **Step 6: Commit checkpoint**

Nothing to commit here (Step 2 already pushed); confirm `git status` is clean before moving on.

---

### Task 2: Extract `CalenbarPanelViewModel` from `MenuBuilder`

**Files:**
- Create: `MeetingBar/UI/StatusBar/CalenbarPanelViewModel.swift`
- Create: `MeetingBarLogicTests/CalenbarPanelViewModelTests.swift`
- Modify: `Package.swift` (add both new files to `MeetingBarLogic` target `sources` and `MeetingBarLogicTests` respectively)

`MenuBuilder.meetingSummaryPresentation(for:)` and the top-section assembly (`buildTopSection`/`buildMeetingControlSection`) already produce well-shaped data (`MeetingSummaryPresentation`); the only reason they return `[NSMenuItem]` is the render target. `CalenbarPanelViewModel` reuses that same data shape but as plain, `Equatable`, AppKit-free structs the new SwiftUI views can render directly — and that `swift test` can verify without Xcode.

- [ ] **Step 1: Write the failing test for the primary-section view model**

```swift
// MeetingBarLogicTests/CalenbarPanelViewModelTests.swift
import XCTest
@testable import MeetingBarLogic

final class CalenbarPanelViewModelTests: XCTestCase {
    func test_primarySection_withNextEvent_producesSummaryAndAgenda() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let next = MBEvent.stub(
            title: "Stand Up",
            startDate: now.addingTimeInterval(4 * 60),
            endDate: now.addingTimeInterval(19 * 60)
        )
        let state = StatusBarMenuState.stub(nextEvent: next, todayEvents: [next])

        let viewModel = CalenbarPanelViewModel.build(from: state, now: now, isFantasticalInstalled: false)

        XCTAssertEqual(viewModel.summary?.eventTitle, "Stand Up")
        XCTAssertEqual(viewModel.agenda.count, 1)
        XCTAssertEqual(viewModel.agenda.first?.title, "Stand Up")
    }

    func test_primarySection_withNoUpcomingEvent_producesEmptyState() {
        let state = StatusBarMenuState.stub(nextEvent: nil, todayEvents: [])
        let viewModel = CalenbarPanelViewModel.build(from: state, now: Date(), isFantasticalInstalled: false)
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.agenda.isEmpty)
        XCTAssertNotNil(viewModel.emptyStateMessage)
    }
}
```

Note: no shared `.stub(...)` factory exists for `MBEvent`/`StatusBarMenuState` — `StatusBarTitlePolicyTests.swift`, `StatusBarIconPolicyTests.swift`, and `StatusBarPresentationPolicyTests.swift` each write bespoke private local builder functions instead. Follow that same pattern rather than assuming a shared helper. `MBEvent`'s real initializer (`MeetingBar/Calendar/MBEvent.swift`) has no defaults for `calendar: MBCalendar`, `status: MBEventStatus`, `organizer: MBEventOrganizer?`, `notes`, `location`, and `url`, and its `meetingSummaryPresentation` path reads `calendar.email` internally — so a usable test builder needs to construct a minimal valid `MBCalendar` too. Read `MBEvent.swift`'s full initializer signature first and write a small private `makeEvent(title:startDate:endDate:)` helper in the new test file that fills the required fields with reasonable dummy values, rather than the one-line `.stub(...)` shorthand shown above (that line is illustrative of intent, not literal code to copy).

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter CalenbarPanelViewModelTests
```
Expected: FAIL — `CalenbarPanelViewModel` doesn't exist yet.

- [ ] **Step 3: Implement `CalenbarPanelViewModel` by moving the two pure functions out of `MenuBuilder`, not by instantiating it**

`MenuBuilder.swift` imports `Cocoa` *and* the third-party `KeyboardShortcuts` package, and `Package.swift` currently declares **zero external dependencies** for the `MeetingBarLogic` target — so neither "add the whole file" nor "construct a `MenuBuilder` instance from the logic package" is viable; `MenuBuilder` can't be referenced from SPM-buildable code at all. Instead, **move** `meetingSummaryPresentation(for:)` (`MenuBuilder.swift:69`) and `eventTimePresentation(for:)` (`MenuBuilder.swift:669`, currently `private`) out of `MenuBuilder` entirely, rewritten as free functions that take their inputs as parameters instead of reading `self.state`/`self.now`/`self.isFantasticalInstalled`. Put them in the new file below, and change `MenuBuilder` to call these free functions instead of its own (now-removed) methods — this is a relocation, not a duplication, so there's exactly one implementation.

This file lives at `MeetingBar/UI/StatusBar/CalenbarPanelViewModel.swift` and, like `StatusBarPresentation.swift` today, is compiled twice: once as a normal member of the app target (visible to `MenuBuilder.swift` and everything else in `MeetingBar/`), and once via its explicit entry in `Package.swift`'s `MeetingBarLogic` `sources` list, which builds it in isolation for `swift test`. Keep it free of `Cocoa`/`AppKit`/`SwiftUI` imports — `Foundation` only — so that isolated build keeps working.

```swift
// MeetingBar/UI/StatusBar/CalenbarPanelViewModel.swift
import Foundation

struct CalenbarAgendaRow: Equatable, Identifiable {
    let id: String
    let title: String
    let timeRangeText: String
    let meetingService: MeetingServices?
    let isCurrent: Bool
}

struct CalenbarPanelViewModel: Equatable {
    var summary: MeetingSummaryPresentation?
    var agenda: [CalenbarAgendaRow]
    var emptyStateMessage: String?

    static func build(from state: StatusBarMenuState, now: Date, isFantasticalInstalled: Bool) -> CalenbarPanelViewModel {
        guard let next = state.nextEvent else {
            return CalenbarPanelViewModel(
                summary: nil,
                agenda: [],
                emptyStateMessage: "status_bar_no_upcoming_events".loco()
            )
        }

        let summary = meetingSummaryPresentation(for: next, state: state, now: now, isFantasticalInstalled: isFantasticalInstalled)

        let agenda = state.todayEvents.map { event -> CalenbarAgendaRow in
            let time = eventTimePresentation(for: event, now: now)
            let isCurrent = event.startDate <= now && event.endDate > now
            return CalenbarAgendaRow(
                id: event.id,
                title: event.title.isEmpty ? "status_bar_no_title".loco() : event.title,
                timeRangeText: event.isAllDay ? time.start : "\(time.start) – \(time.end)",
                meetingService: event.meetingLink?.service,
                isCurrent: isCurrent
            )
        }

        return CalenbarPanelViewModel(summary: summary, agenda: agenda, emptyStateMessage: nil)
    }
}

// Moved from MenuBuilder (was `meetingSummaryPresentation(for:)` / `eventTimePresentation(for:)`,
// instance methods reading `self.state`/`self.now`/`self.isFantasticalInstalled`) so this logic
// is callable from both the AppKit app target and the AppKit-free MeetingBarLogic package.
// Preserve their exact existing bodies — only change is threading former `self.*` reads through
// as explicit parameters. See MenuBuilder.swift:69-114 and :669-694 for the logic being moved.
func meetingSummaryPresentation(for event: MBEvent, state: StatusBarMenuState, now: Date, isFantasticalInstalled: Bool) -> MeetingSummaryPresentation {
    fatalError("move the real implementation here verbatim from MenuBuilder.swift:69-114")
}

func eventTimePresentation(for event: MBEvent, now: Date) -> EventTimePresentation {
    fatalError("move the real implementation here verbatim from MenuBuilder.swift:669-694")
}
```

The two `fatalError` bodies above are placeholders marking exactly what to move — replace them with the real bodies copied from `MenuBuilder.swift`, adapting only the `self.x` → parameter references, then delete the original methods from `MenuBuilder.swift` and update its remaining call sites (`MenuBuilder.swift:63`, `:91`, `:657`, and wherever else `meetingSummaryPresentation`/`eventTimePresentation` are called) to call these free functions instead.

- [ ] **Step 4: Add the new files to `Package.swift`**

Add `"UI/StatusBar/CalenbarPanelViewModel.swift"` to the `MeetingBarLogic` target's `sources` array (alongside the existing `"UI/StatusBar/StatusBarPresentation.swift"` entry), and confirm `MeetingBarLogicTests` picks up the new test file automatically (its `path:` already points at the whole `MeetingBarLogicTests` directory, so no change needed there — verify by checking `Package.swift`'s `testTarget` block).

Note: `MenuBuilder.swift` itself is *not* currently in the SPM sources list (it depends on `Cocoa`/`NSMenuItem`), so `CalenbarPanelViewModel.swift` constructing a `MenuBuilder` internally means `MenuBuilder.swift` needs to be addable to the SPM target too, or `meetingSummaryPresentation`/`eventTimePresentation`'s logic needs extracting one level further into AppKit-free helper functions `CalenbarPanelViewModel` calls directly instead of instantiating `MenuBuilder`. Resolve this in Step 3 based on what actually compiles — if `MenuBuilder.swift` pulls in `Cocoa` imports at the file level, prefer extracting the two needed pure functions rather than adding the whole file to the logic target.

- [ ] **Step 5: Run test to verify it passes**

```bash
swift test --filter CalenbarPanelViewModelTests
```
Expected: PASS.

- [ ] **Step 6: Run the full logic test suite to confirm no regressions**

```bash
swift test
```
Expected: all existing tests plus the two new ones pass.

- [ ] **Step 7: Commit**

```bash
git add MeetingBar/UI/StatusBar/CalenbarPanelViewModel.swift MeetingBarLogicTests/CalenbarPanelViewModelTests.swift Package.swift MeetingBar/UI/StatusBar/MenuBuilder.swift
git commit -m "Add CalenbarPanelViewModel: AppKit-free data model for the glass panel"
```

---

### Task 3: Bump `Package.swift` deployment target

**Files:**
- Modify: `Package.swift:8` (`.macOS(.v12)` → `.macOS(.v26)`)

- [ ] **Step 1: Make the change**

```swift
platforms: [
    .macOS(.v26)
],
```

- [ ] **Step 2: Verify**

```bash
swift build && swift test
```
Expected: both succeed (this bump only affects the SPM platform gate; it doesn't change any code behavior).

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "Bump MeetingBarLogic package minimum to macOS 26"
```

---

## ⚠️ Checkpoint: Phase 2 requires Xcode 26

Everything below needs full Xcode 26 installed (`xcode-select -p` should point inside `/Applications/Xcode.app`, not `CommandLineTools`) — it touches the `.xcodeproj`, asset catalogs, `NSPanel`/`NSHostingView` integration, and needs `xcodebuild` to build/test/run the actual app. If Xcode isn't installed yet, stop here and install it (App Store → Xcode, or `xcodes install` if using the `xcodes` CLI) before continuing.

---

## Phase 2 — Requires Xcode 26

### Task 4: Rename app identifiers

**Files:**
- Modify: `MeetingBar.xcodeproj/project.pbxproj` (44 occurrences of "MeetingBar")
- Modify: `MeetingBar.xcodeproj/xcshareddata/xcschemes/MeetingBar.xcscheme` → rename to `Calenbar.xcscheme`
- Rename directory: `MeetingBar.xcodeproj` → `Calenbar.xcodeproj`
- Rename directory: `MeetingBar/` (app target source root) → `Calenbar/`

Scope: only rename **app-identity** strings — `PRODUCT_BUNDLE_IDENTIFIER` (`leits.MeetingBar` → e.g. `dev.armendu.Calenbar`), `PRODUCT_NAME`/target/scheme names, and the two directories above. Do **not** rename the internal Swift module (`MeetingBarLogic` stays as-is — Task 2 already depends on that name) or type names like `MBEvent`/`MeetingBar*` classes — that's a much larger, purely cosmetic diff with no user-facing benefit and high risk of breaking the SPM package's `sources` paths (which are relative to `MeetingBar/`, so confirm `Package.swift`'s `path: "MeetingBar"` is updated to `path: "Calenbar"` if that directory is renamed, or keep the source directory name `MeetingBar/` and only rename the `.xcodeproj`/scheme/bundle-id if that's simpler — decide based on how many `Package.swift` paths would need touching, and prefer the smaller diff).

- [ ] **Step 1:** Open the project in Xcode, use Xcode's own project rename (select the project in the navigator → rename) for the `.xcodeproj`/scheme, which handles most `project.pbxproj` references safely; then manually update `PRODUCT_BUNDLE_IDENTIFIER` for both the app and test targets in Build Settings.
- [ ] **Step 2:** `grep -c "MeetingBar" MeetingBar.xcodeproj/project.pbxproj` (or `Calenbar.xcodeproj/...` if renamed) to confirm remaining occurrences are only internal type/module names, not product/bundle identifiers.
- [ ] **Step 3:** Build: `xcodebuild -project Calenbar.xcodeproj -scheme Calenbar -configuration Debug build`. Expected: `BUILD SUCCEEDED`.
- [ ] **Step 4:** Commit: `git add -A && git commit -m "Rename app identity to Calenbar (bundle ID, product, scheme)"`.

---

### Task 5: Bump Xcode project deployment target

**Files:**
- Modify: `Calenbar.xcodeproj/project.pbxproj` (`MACOSX_DEPLOYMENT_TARGET = 12.0;` → `26.0`, both Debug and Release configurations, app and test targets)

- [ ] **Step 1:** In Xcode, set Deployment Target to macOS 26.0 in Build Settings for all targets (or edit `project.pbxproj` directly — there are multiple `MACOSX_DEPLOYMENT_TARGET` entries, one per target/configuration pair; update all of them).
- [ ] **Step 2:** Build: `xcodebuild -project Calenbar.xcodeproj -scheme Calenbar build`. Expected: `BUILD SUCCEEDED`.
- [ ] **Step 3:** Commit: `git add Calenbar.xcodeproj/project.pbxproj && git commit -m "Bump deployment target to macOS 26 (required for Liquid Glass APIs)"`.

---

### Task 6: Fix the status-bar leading-space bug and set Calenbar's compact-countdown defaults

**Files:**
- Modify: `Calenbar/UI/StatusBar/StatusBarItemController.swift:511-515` (`StatusBarTitleRenderer.attributedTitle`)
- Modify: `Calenbar/Extensions/DefaultsKeys.swift:61,62,64-65` (default values for `eventTitleFormat`, `eventTimeFormat`, `eventTitleIconFormat`)
- Test: `CalenbarTests/StatusBarItem/MenuBuilderTests.swift` (existing `StatusBarTitleRendererTests`, around line 1330)

- [ ] **Step 1: Write the failing test**

Add to the existing `StatusBarTitleRendererTests` class:

```swift
func test_attributedTitle_emptyTitleWithShowTime_hasNoLeadingSpace() {
    let presentation = StatusBarPresentation(
        mode: .nextEvent,
        title: "",
        time: "4m",
        tooltip: nil,
        icon: .asset("iconCalendar"),
        layout: .inline(showTime: true),
        titleStyle: .normal,
        removeDeliveredNotifications: false
    )
    let title = StatusBarTitleRenderer.attributedTitle(for: presentation)
    XCTAssertEqual(title.string, "4m")
}
```

(Match this to whichever `StatusBarPresentation` initializer the existing tests around line 1330-1372 already use — copy their construction pattern rather than guessing the argument list.)

- [ ] **Step 2: Run to verify it fails**

```bash
xcodebuild test -project Calenbar.xcodeproj -scheme Calenbar -only-testing:CalenbarTests/StatusBarTitleRendererTests/test_attributedTitle_emptyTitleWithShowTime_hasNoLeadingSpace
```
Expected: FAIL — actual string is `" 4m"` (leading space).

- [ ] **Step 3: Fix the renderer**

```swift
// StatusBarItemController.swift, inside `.inline(let showTime)` case
case .inline(let showTime):
    var eventTitle = presentation.title
    if showTime {
        eventTitle = eventTitle.isEmpty ? presentation.time : eventTitle + " " + presentation.time
    }
    return NSAttributedString(
        string: eventTitle,
        attributes: titleAttributes(
            style: presentation.titleStyle,
            font: NSFont.systemFont(ofSize: MenuStyleConstants.defaultFontSize)
        )
    )
```

- [ ] **Step 4: Run to verify it passes**

Same command as Step 2. Expected: PASS.

- [ ] **Step 5: Run the full app test suite for regressions**

```bash
xcodebuild test -project Calenbar.xcodeproj -scheme Calenbar
```
Expected: all pass, including the pre-existing `StatusBarTitleRendererTests` cases (they use non-empty titles, so the `.isEmpty` branch shouldn't affect them — verify this explicitly rather than assuming).

- [ ] **Step 6: Change Calenbar's shipped defaults**

```swift
// DefaultsKeys.swift
static let eventTitleFormat = Key<EventTitleFormat>("eventTitleFormat", default: .none)
static let eventTimeFormat = Key<EventTimeFormat>("eventTimeFormat", default: .show)
static let eventTitleIconFormat = Key<EventTitleIconFormat>(
    "eventTitleIconFormat", default: .eventtype)
```

Run the app once locally (`xcodebuild -project Calenbar.xcodeproj -scheme Calenbar build` then launch the built `.app`, or run from Xcode) with a test calendar event to visually confirm the status bar now shows an icon + bare countdown like "4m" with no leading space or extra text. This needs a real Calendar.app event with a matching calendar selected in onboarding — use a throwaway local calendar event a few minutes out.

- [ ] **Step 7: Commit**

```bash
git add Calenbar/UI/StatusBar/StatusBarItemController.swift Calenbar/Extensions/DefaultsKeys.swift CalenbarTests/StatusBarItem/MenuBuilderTests.swift
git commit -m "Fix status-bar leading-space bug; default to icon + compact countdown"
```

---

### Task 7: Build the Liquid Glass panel views

> **Status: implemented ahead of schedule**, as prep work while blocked on the Xcode install (branch `calenbar-glass-panel`, commits `155d276`→`9306546`). Verified compile-clean via ad-hoc `swiftc`/throwaway-SPM probes against the real macOS 26 SDK and real dependencies (no XCTest/`xcodebuild` available in this environment) — **not yet click-tested on a real device.** The actual implementation matches this task's intent but diverged from its literal code sketch in ways worth knowing before re-reading it: `MeetingSummaryView` is reused as-is inside the panel rather than rebuilt, a "More…" row was added (see Task 8's note below for why), and all new user-facing strings go through `.loco()`/`Localizable.strings` rather than being hardcoded. See the updated spec's "Panel mechanics" section and the commit messages on that branch for the full story, including two real bugs a review pass caught and fixed (a left-click double-fire, a dead Esc handler) and one still-open risk (Esc's Input Monitoring dependency).

**Files:**
- Create: `Calenbar/UI/StatusBar/CalenbarGlassPanelView.swift`
- Create: `Calenbar/UI/StatusBar/CalenbarAgendaRowView.swift`

Base these on the existing `MeetingSummaryView.swift` (`Calenbar/UI/StatusBar/MeetingSummaryView.swift`) — same data (`MeetingSummaryPresentation`), same hover/tap interaction pattern — but wrapped in `.glassEffect()` containers instead of a flat `Color.clear`/`Color.primary.opacity` background, and composed with the new `CalenbarAgendaRow` list from Task 2's view model.

- [ ] **Step 1:** Sketch the panel container:

```swift
import SwiftUI

struct CalenbarGlassPanelView: View {
    let viewModel: CalenbarPanelViewModel
    let onJoin: () -> Void
    let onSelectAgendaRow: (CalenbarAgendaRow) -> Void

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 8) {
                if let summary = viewModel.summary {
                    MeetingSummaryView(
                        presentation: summary,
                        providerIcon: getIconForMeetingService(summary.meetingService),
                        onJoin: onJoin
                    )
                } else {
                    Text(viewModel.emptyStateMessage ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if !viewModel.agenda.isEmpty {
                    Divider()
                    ForEach(viewModel.agenda) { row in
                        CalenbarAgendaRowView(row: row)
                            .onTapGesture { onSelectAgendaRow(row) }
                    }
                }
            }
            .padding(12)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .frame(width: 380)
    }
}
```

Verify the exact `.glassEffect()`/`GlassEffectContainer` call signatures against the macOS 26 SDK once Xcode is available (API shape may differ slightly from this sketch — Xcode's autocomplete/docs are the source of truth, not this plan).

- [ ] **Step 2:** Write `CalenbarAgendaRowView` (title, time range, current-meeting highlight) following the visual pattern already established in `MeetingSummaryView.swift`'s hover/cursor handling.

- [ ] **Step 3:** Add `#Preview` blocks for both views using representative fixture data (mirror `MeetingSummaryView.swift:99-111`'s existing preview pattern), and check them render correctly in Xcode's canvas.

- [ ] **Step 4:** Commit:

```bash
git add Calenbar/UI/StatusBar/CalenbarGlassPanelView.swift Calenbar/UI/StatusBar/CalenbarAgendaRowView.swift
git commit -m "Add Liquid Glass panel SwiftUI views"
```

---

### Task 8: Custom `NSPanel` host and status-item wiring

> **Status: implemented ahead of schedule**, alongside Task 7 (same branch/commits). **Important correction to this task's own file description below**: "right-click → existing `NSMenu` unchanged" is wrong — right-click was never a menu trigger to begin with, it's `joinNextMeeting()`, an existing instant-join shortcut (confirmed by reading the actual pre-existing `StatusBarItemController.statusMenuBarAction`). That shortcut is what's left unchanged; the classic `NSMenu` is reached via a new "More…" row inside the glass panel instead. Also implemented beyond this task's original sketch: an `NSHostingView` subclass overriding `acceptsFirstMouse(for:)` (without it, every click in the panel would need two taps — a well-known gotcha for permanently-non-key custom popups), and a fix for the status item button double-firing its action per left-click (harmless under the old blocking `NSMenu` path, but caused an open-then-immediate-close under the new non-blocking panel). See the spec's "Panel mechanics" section for the full list of what changed and why.

**Files:**
- Create: `Calenbar/UI/StatusBar/CalenbarPanelController.swift`
- Modify: `Calenbar/UI/StatusBar/StatusBarItemController.swift` (left-click → new panel, right-click → existing `NSMenu` unchanged)

- [ ] **Step 1:** Implement the panel controller per the spec's "Panel mechanics" section — `.nonactivatingPanel` style mask, appropriate window level, dismissal on click-outside/Esc/re-click/resign-key/screen-lock, positioned under the status item and clamped to screen bounds:

```swift
import AppKit
import SwiftUI

@MainActor
final class CalenbarPanelController: NSObject {
    private var panel: NSPanel?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    func toggle(near statusItemButton: NSStatusBarButton, viewModel: CalenbarPanelViewModel, onJoin: @escaping () -> Void, onSelectAgendaRow: @escaping (CalenbarAgendaRow) -> Void) {
        if panel != nil {
            dismiss()
            return
        }
        show(near: statusItemButton, viewModel: viewModel, onJoin: onJoin, onSelectAgendaRow: onSelectAgendaRow)
    }

    private func show(near button: NSStatusBarButton, viewModel: CalenbarPanelViewModel, onJoin: @escaping () -> Void, onSelectAgendaRow: @escaping (CalenbarAgendaRow) -> Void) {
        let hosting = NSHostingView(rootView: CalenbarGlassPanelView(
            viewModel: viewModel, onJoin: { [weak self] in onJoin(); self?.dismiss() },
            onSelectAgendaRow: { [weak self] row in onSelectAgendaRow(row); self?.dismiss() }
        ))
        let panel = NSPanel(
            contentRect: .init(origin: .zero, size: hosting.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        guard let buttonWindow = button.window, let screen = buttonWindow.screen else { return }
        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.frame)
        var origin = NSPoint(
            x: buttonFrameOnScreen.midX - hosting.fittingSize.width / 2,
            y: buttonFrameOnScreen.minY - hosting.fittingSize.height
        )
        origin.x = min(max(origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - hosting.fittingSize.width)
        panel.setFrameOrigin(origin)

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        installDismissalMonitors()
    }

    func dismiss() {
        removeDismissalMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    private func installDismissalMonitors() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss(); return nil } // Esc
            return event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(dismissFromNotification), name: NSApplication.didResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(dismissFromNotification), name: NSWorkspace.screensDidSleepNotification, object: nil)
        // Screen *lock* (vs. sleep) is a separate event delivered on the distributed
        // notification center, not NSWorkspace.notificationCenter — without this,
        // locking the screen while the panel is open won't dismiss it.
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(dismissFromNotification), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
    }

    private func removeDismissalMonitors() {
        if let m = globalClickMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        globalClickMonitor = nil
        localKeyMonitor = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func dismissFromNotification() { dismiss() }
}
```

This is a starting sketch, not final code:
- Verify `NSPanel` level/style-mask choices against Apple's current guidance once building in Xcode (e.g. whether `.statusBar` level plus `.nonactivatingPanel` fully prevents activating the app on click; test manually), and confirm the global monitor correctly ignores clicks on the status item button itself (otherwise clicking the button to toggle would dismiss-then-immediately-reshow or double-toggle — test this interaction explicitly).
- `hosting.fittingSize` is read at lines 491/505-506 immediately after constructing `NSHostingView`, before it's attached to any window — SwiftUI frequently reports `.zero` or a stale size at that point since layout hasn't run yet. Don't trust this sketch's sizing as-is: either set `contentRect` to a reasonable fixed/estimated size up front and let SwiftUI's `.frame(width:)` (already on `CalenbarGlassPanelView`) drive the real layout, or attach the hosting view to the panel first and re-read/re-apply `fittingSize` (and reposition) in a follow-up pass once layout has actually occurred. Confirm the final approach doesn't show a visibly wrong-sized panel for a frame or two on first appearance.

- [ ] **Step 2:** Wire into `StatusBarItemController`: change the left-click handler to call `CalenbarPanelController.toggle(...)` with a `CalenbarPanelViewModel` built from current state, subscribing to the same Combine pipeline already driving `updateTitle()`/`updateMenu()` (see `CalendarSync.swift:192`'s `Timer.publish` and the `Defaults.publisher` chains in `StatusBarItemController`'s `init`). Rebuild and re-render `CalenbarPanelViewModel` on every tick from that pipeline *while the panel is open*, not just when it's (re)opened — this is what makes the countdown shown in the panel actually tick down live rather than freezing at whatever it read on open. Leave the right-click handler invoking the existing `statusItemMenu`/`MenuBuilder` path completely unchanged.

- [ ] **Step 3:** Manually verify: left-click opens the glass panel without activating/focusing the app or stealing focus from the frontmost app; right-click still shows the full classic menu with every existing item; clicking outside, pressing Esc, re-clicking the status item, and locking the screen (Cmd+Ctrl+Q) all dismiss the panel; clicking "Join" opens the meeting link and dismisses the panel; **leave the panel open with an upcoming event and confirm the countdown text visibly ticks down (e.g. "4m" → "3m") without closing/reopening it** — this is the spec's explicit "not a one-shot snapshot" requirement, so don't skip it.

- [ ] **Step 4:** Commit:

```bash
git add Calenbar/UI/StatusBar/CalenbarPanelController.swift Calenbar/UI/StatusBar/StatusBarItemController.swift
git commit -m "Wire custom Liquid Glass NSPanel into left-click; keep classic NSMenu on right-click"
```

---

### Task 9: Accessibility pass

**Files:**
- Modify: `Calenbar/UI/StatusBar/CalenbarGlassPanelView.swift`, `CalenbarAgendaRowView.swift`, `CalenbarPanelController.swift`

- [ ] **Step 1:** Add `.accessibilityLabel`/`.accessibilityHint` to the Join button and each agenda row (e.g. "Stand Up, 10:00 to 10:15, double tap to open").
- [ ] **Step 2:** Add keyboard focus handling to `CalenbarPanelController`/the SwiftUI views — arrow keys move between agenda rows, Return activates the focused row, Esc dismisses (already covered by Task 8's key monitor). Use SwiftUI's `@FocusState`/`.focusable()` or an `NSResponder`-based approach depending on what's cleaner once you're in the actual codebase — decide once building, don't over-specify here.
- [ ] **Step 3:** Manually test with VoiceOver on (Cmd+F5): confirm the panel announces as a coherent region and each row/button is reachable and labeled.
- [ ] **Step 4:** Manually test with Reduce Transparency enabled (System Settings → Accessibility → Display): confirm the panel remains legible and doesn't render as a broken/transparent void.
- [ ] **Step 5:** Commit: `git add -A && git commit -m "Accessibility: keyboard nav, VoiceOver labels, Reduce Transparency check for glass panel"`.

---

### Task 10: Manual end-to-end verification

- [ ] Run the built app, add a test Calendar.app event a few minutes out, confirm: status bar shows icon + compact countdown; left-click shows the glass panel with correct summary + agenda; right-click shows the untouched classic menu; Join works; all dismissal triggers (click-outside, Esc, re-click, screen lock) work.
- [ ] Leave the glass panel open and watch the countdown tick down live (e.g. "4m" → "3m") without closing/reopening it — confirms the panel isn't a frozen one-shot snapshot.
- [ ] Take screenshots of both menu states (glass panel, classic menu) for the README.
- [ ] No commit — this is a verification checkpoint, not a code change.

---

### Task 11: GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1:** Check `actions/runner-images` (github.com/actions/runner-images) release notes for the current macOS-hosted runner image and confirm which one ships Xcode with macOS 26 SDK support; pin to that specific image (e.g. `macos-15` or whatever is current at implementation time — do not use `macos-latest`, per the spec's risk note).
- [ ] **Step 2:** Write the workflow: on tag push (`v*`), `xcodebuild -project Calenbar.xcodeproj -scheme Calenbar -configuration Release build`, locate the built `.app`, zip it, attach to a GitHub Release via `gh release create` or `softprops/action-gh-release`.
- [ ] **Step 3:** Tag a test release (e.g. `v0.1.0-test`) and confirm the workflow runs green and produces a downloadable `.app.zip` asset.
- [ ] **Step 4:** Commit: `git add .github/workflows/release.yml && git commit -m "Add release workflow: build and zip .app on tag push"`.

---

### Task 12: Homebrew tap and Cask formula

**Files:**
- Create (new repo): `armendu/homebrew-calenbar/Casks/calenbar.rb`

- [ ] **Step 1:** `gh repo create armendu/homebrew-calenbar --public --clone` (Homebrew tap naming convention requires the `homebrew-` prefix).
- [ ] **Step 2:** Write the Cask:

```ruby
cask "calenbar" do
  version "0.1.0"
  sha256 "<sha256 of the release .app.zip>"

  url "https://github.com/armendu/Calenbar/releases/download/v#{version}/Calenbar.app.zip"
  name "Calenbar"
  desc "Liquid Glass menu bar app for your next macOS Calendar meeting"
  homepage "https://github.com/armendu/Calenbar"

  depends_on macos: ">= :tahoe"

  app "Calenbar.app"

  caveats <<~EOS
    Calenbar is not notarized. On first launch, right-click the app in
    Finder and choose "Open", then confirm in the dialog that appears.
  EOS
end
```
Verify `>= :tahoe` is the correct current Cask DSL symbol for macOS 26 at implementation time (Homebrew's OS-version symbols are a moving target — check `brew cask-repair`/current Homebrew docs rather than trusting this plan's guess).

- [ ] **Step 3:** `brew tap armendu/calenbar && brew install --cask calenbar` on this machine; confirm it installs and launches (with the expected unsigned-app Gatekeeper prompt, dismissed via the caveat's instructions).
- [ ] **Step 4:** Commit and push the tap repo.

---

### Task 13: README and license-compliance docs

**Files:**
- Modify: `README.md`
- Create: `CHANGES.md`

- [ ] **Step 1:** Rewrite the top of `README.md`: Calenbar name/description, screenshots from Task 10, macOS 26+ requirement, `brew tap armendu/calenbar && brew install --cask calenbar` install instructions, and a short "This is a UI-focused fork of [MeetingBar](https://github.com/leits/MeetingBar)" note.
- [ ] **Step 2:** Write `CHANGES.md` listing every file modified from upstream and a one-line description of the change (satisfies Apache 2.0 §4(b)) — pull the list from `git log --stat` against the `upstream/master` merge-base rather than reconstructing it by memory.
- [ ] **Step 3:** Confirm `LICENSE` is untouched and copyright headers in modified files (Task 6, 8) weren't stripped.
- [ ] **Step 4:** Commit: `git add README.md CHANGES.md && git commit -m "Update README and add CHANGES.md for the Calenbar fork"`.
