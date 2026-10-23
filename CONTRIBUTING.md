# Contributing to Calenbar

Calenbar welcomes focused bug fixes, meeting-service integrations, reliability improvements, translations, and documentation updates.

## GitHub Workflow

Use GitHub issues for public bugs and feature requests. Keep pull requests small enough to review in one pass, and describe:

* What changed and why
* User-visible behavior changes
* Tests or validation commands you ran
* Any dependency, entitlement, signing, URL scheme, script, workflow, or base-localization changes

## Bug Reports

Good bug reports include:

* Calenbar version and macOS version
* Calendar provider: macOS Calendar or Google Calendar
* Meeting service when relevant: Zoom, Google Meet, Microsoft Teams, Webex, etc.
* Steps to reproduce
* Expected behavior and actual behavior
* Whether manual refresh, relaunch, or reconnect changes the result
* Sanitized event title, description, location, URL fields, screenshots, or logs when useful

## Building Locally

Calenbar is a macOS app built with Xcode, Swift 6, AppKit, SwiftUI, and Xcode-managed Swift Package dependencies.

For local signing, create `XCConfig/DevTeamOverride.xcconfig` with your Apple development team. This file is git-ignored, so you do not need to change the Xcode project:

```xcconfig
DEVELOPMENT_TEAM = <your development team id>
```

Common validation commands:

```bash
make build            # Debug build
make test             # SwiftPM logic tests + Xcode app-hosted tests with coverage
make test-logic       # Hostless SwiftPM logic tests only
make lint             # SwiftLint (pinned by the project, nothing to install)
make validate-strings # Verify English localization keys used by .loco()
```

Unsigned local Debug builds may print entitlement or signing warnings because code signing is disabled. That warning is expected for local verification; signed Release builds still need a real signing check.

## Architecture And Dependencies

Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before changing app flow, calendar providers, meeting-link detection, notifications, status-bar rendering, settings, package dependencies, entitlements, or release-sensitive configuration.

Direct app dependencies are Xcode Swift Package references pinned by `Calenbar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. `Package.swift` defines the hostless `MeetingBarLogic` package used for fast policy tests. Do not update only `Package.resolved`; change the Xcode package requirement intentionally and review the resolved diff.

Update `CHANGELOG.md` for user-visible changes and notable architecture, dependency, or release-process changes. For new source strings, update `Calenbar/Resources /Localization /en.lproj/Localizable.strings` and run `make validate-strings`; non-English translations are managed through Weblate.

## Releasing

A release is a version bump (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both build configurations) plus a `CHANGELOG.md` section for that version, merged through `development` into `master`. The release workflow then builds the DMG, tags `v<version>` and publishes it.

`make dmg` runs `Scripts/verify_release_app.sh` on the signed app before packaging, and so does the release workflow. It fails the release when the version doesn't match `MARKETING_VERSION`, when the calendar, sandbox or network entitlements or the calendar usage description are missing, or when the signature, hardened runtime or universal binary is wrong. None of these crash the app: without calendar access EventKit just returns no calendars.

Tests can't show the macOS permission prompt, so before merging a release into `master`, smoke-test the DMG by hand:

1. Run `make dmg`, quit Calenbar, and replace `/Applications/Calenbar.app` with the app from `build/Calenbar-<version>.dmg`.
2. Run `tccutil reset Calendar dev.armendu.Calenbar`. Every ad hoc build has a new signature, so macOS treats each release as never asked; this reproduces that.
3. Open Calenbar. The calendar prompt must appear. After Allow, today's events must show in the panel.
4. In System Settings › Privacy & Security › Calendars, switch Calenbar to Add Events Only. The panel must show Grant permission instead of an empty agenda. Switch it back to Full Access.

## License

By contributing, you agree that your contributions are licensed under the Apache License 2.0.
