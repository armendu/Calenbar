# Calenbar

A macOS menu-bar app that shows your current or next meeting and joins it in one click, with a Liquid Glass panel for macOS 26.

Calenbar is a fork of [MeetingBar](https://github.com/leits/MeetingBar) by [Andrii Leitsius (leits)](https://github.com/leits) and the MeetingBar contributors. It changes the interface; calendar access, meeting-link detection and notifications come from MeetingBar. Calenbar is not affiliated with or endorsed by the MeetingBar project.

## Requirements

macOS 26 (Tahoe) or later.

## Install

There are no prebuilt releases yet. Build from source with Xcode 26:

```bash
git clone https://github.com/armendu/Calenbar.git
cd Calenbar
make build
```

The app is built to `build/DerivedData/Build/Products/Debug/Calenbar.app`. Local builds are unsigned: the first time you open the app, right-click it in Finder and choose **Open**.

## Features

- The current or next meeting in the menu bar, with a calendar icon showing today's date.
- Left-click opens a panel with the next meeting, a Join button and today's agenda. **More…** opens the full menu, with a "This week" section, bookmarks and preferences.
- Works with macOS Calendar (iCloud, Google, Exchange, Office 365 and other accounts added there) or Google Calendar directly.
- Detects links for 50+ meeting services, including Google Meet, Zoom, Microsoft Teams, Webex, Slack and Discord ([list](https://github.com/leits/MeetingBar/discussions/108)).
- Notifications and full-screen reminders before meetings.
- Keyboard shortcuts, per-service browser or app choice, Shortcuts and AppleScript hooks.

## Privacy

Calenbar doesn't collect data. Your calendar is read only to show your meetings and open their links.

## Contributing

Bug reports and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). When reporting a bug, include your Calenbar and macOS versions, the calendar provider and the meeting service.

## License

Calenbar is licensed under the [Apache License 2.0](LICENSE), the same license as MeetingBar.

- MeetingBar's code is copyright Andrii Leitsius and the MeetingBar contributors. Their copyright notices are kept in the source files.
- Calenbar modifies that code. Changes are recorded in the git history and in [CHANGELOG.md](CHANGELOG.md).
- The app icon is MeetingBar's original logo, made by [Miroslav Rajkovic](https://www.rajkovic.co/).

Calenbar uses these open-source packages, each under its own license:

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [Defaults](https://github.com/sindresorhus/Defaults)
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin)
- [AppAuth-iOS](https://github.com/openid/AppAuth-iOS)
