[![Stand With Ukraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/banner-direct-single.svg)](https://stand-with-ukraine.pp.ua)

[![GitHub license](https://img.shields.io/github/license/armendu/Calenbar.svg)](https://github.com/armendu/Calenbar/blob/master/LICENSE)
[![GitHub all releases](https://img.shields.io/github/downloads/armendu/Calenbar/total.svg)](https://github.com/armendu/Calenbar/releases/)

**Calenbar** is a lightweight macOS menu-bar app that shows your current or next calendar meeting and lets you join it in one click — reimagined around macOS 26's Liquid Glass design language.

It keeps meetings visible in the status bar, detects meeting links from calendar events, supports macOS Calendar and Google Calendar, and works with 50+ meeting services including Google Meet, Zoom, Microsoft Teams, Webex, and Discord.

Calenbar is free, open source, and privacy-respecting.

<img src="screenshot.png" width="700">

## About this fork

Calenbar is a UI/UX-focused fork of [leits/MeetingBar](https://github.com/leits/MeetingBar) (Apache 2.0). MeetingBar already handles the hard parts — EventKit integration, meeting-link detection for 50+ services, notifications — and does them well. Calenbar's job is the surface: it replaces MeetingBar's stock `NSMenu` dropdown with a custom **Liquid Glass panel** (the translucent material macOS 26 uses in Control Center and other system surfaces) for the primary "next meeting" flow, while keeping every existing MeetingBar feature reachable.

Left-clicking the status item opens the glass panel — current/next meeting summary, one-click Join, and today's agenda. The full classic menu (bookmarks, alternate links, preferences, and everything else) is still one click away via the panel's "More…" row.

All calendar and meeting logic is inherited from MeetingBar and stays untouched. Full credit for that foundation goes to [leits](https://github.com/leits) and the MeetingBar contributors.

## Install

Calenbar requires **macOS 26.0 (Tahoe) or later** — the Liquid Glass panel depends on the macOS 26 SDK.

### Homebrew

```bash
brew tap armendu/calenbar
brew install --cask calenbar
```

Calenbar is distributed unsigned (no Apple Developer ID). On first launch, right-click the app in Finder and choose **Open** to bypass Gatekeeper, then confirm.

### Build from source

```bash
git clone https://github.com/armendu/Calenbar.git
cd Calenbar
make build
```

The built app lands in `build/DerivedData/Build/Products/Debug/Calenbar.app`.

After installing, open Calenbar and go through onboarding to choose your calendar source and preferences.

## Calendar providers

Calenbar works with:

* **macOS Calendar**: use any calendar account synchronized with Calendar.app, including iCloud, Google, Exchange, Office 365, Yahoo, AOL, and others.
* **Google Calendar**: connect Google Calendar directly from Calenbar.

## Features

### See what is next

* Show the current or next meeting in the macOS status bar.
* A Liquid Glass panel on left-click with the meeting summary, Join button, and today's agenda.
* Display meeting title, time, countdown, icon, or meeting service.
* Choose how far ahead a meeting appears in the panel (always, 5 min, 10 min, 15 min, 30 min, 1 h, 2 h, and up).
* Filter all-day, declined, tentative, pending, or linkless events.
* Shorten long meeting titles to keep the menu bar readable.

### Join meetings faster

* Join the current or next online meeting with one click.
* Join the nearest meeting with a global keyboard shortcut.
* Create ad-hoc meetings from your preferred meeting service.
* Open meeting links in a preferred browser or native app per service.
* Open event details in macOS Calendar or Fantastical.

### Get meeting reminders

* Receive macOS notifications before meetings.
* Use full-screen reminders for important meeting starts.
* Dismiss meeting notifications when you no longer need them.
* Configure reminders around your own workflow.

### Customize and automate

* Bookmark recurring meetings and access them quickly.
* Launch Calenbar automatically at login.
* Use Shortcuts and AppleScript integrations.
* Run custom AppleScript, for example to pause music when joining a meeting.

## Supported meeting services

Calenbar supports more than 50 meeting services, including:

Google Meet, Zoom, Microsoft Teams, Webex, GoToMeeting, Skype, Discord, Jitsi, RingCentral, BlueJeans, Whereby, Slack Huddle, FaceTime, LiveKit Meet, Meetecho, StreamYard, and many others.

See the [full supported services list](https://github.com/leits/MeetingBar/discussions/108) from the upstream project.

## Privacy

Calenbar does not collect personal data.

Calendar data is used by the app to show your meetings, detect meeting links, and open the correct meeting action.

## Troubleshooting

If meetings do not appear, links are not detected, or Google Calendar needs reconnecting, install the [latest release](https://github.com/armendu/Calenbar/releases/latest) or [open an issue](https://github.com/armendu/Calenbar/issues/new).

Useful details for bug reports:

* Calenbar version
* macOS version
* Calendar provider: macOS Calendar or Google Calendar
* Meeting service: Zoom, Google Meet, Microsoft Teams, Webex, etc.
* Whether the event is recurring or one-off
* Whether the event is accepted, tentative, pending, declined, or canceled
* Sanitized event title, description, location, and URL fields
* Whether manual refresh changes the behavior
* Screenshots or logs when available

## Contributing

Calenbar welcomes focused fixes, meeting service integrations, translations, reliability improvements, and documentation updates.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Support the upstream project

Calenbar builds entirely on MeetingBar's foundation. If you find it useful, please consider supporting the original author, [leits](https://github.com/leits), through [Patreon](https://www.patreon.com/meetingbar) or [Buy Me a Coffee](https://www.buymeacoffee.com/meetingbar).

## Credits

Calenbar is a fork of [MeetingBar](https://github.com/leits/MeetingBar) by [leits](https://github.com/leits), maintained by [armendu](https://github.com/armendu). Written in Swift 6.

Calenbar also uses these resources:

* [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for managing global keyboard shortcuts
* [Defaults](https://github.com/sindresorhus/Defaults) for managing user settings
* [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) for launch-at-login integration
* [AppAuth-iOS](https://github.com/openid/AppAuth-iOS) for Google Calendar OAuth

Original MeetingBar app logo made by [Miroslav Rajkovic](https://www.rajkovic.co/).

If you encounter any bugs or have a feature request, [open an issue](https://github.com/armendu/Calenbar/issues/new).
