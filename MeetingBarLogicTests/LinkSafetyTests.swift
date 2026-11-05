//
//  LinkSafetyTests.swift
//  MeetingBarLogicTests
//
//  Links Calenbar opens on its own come from invites, Google conference data
//  or the clipboard, so anything that isn't a recognised meeting link must be
//  a web page: other schemes hand off to arbitrary apps (file, ssh, smb, …).
//

import XCTest

@testable import MeetingBarLogic

final class LinkSafetyTests: XCTestCase {
    // MARK: - Web links

    func testOnlyHTTPAndHTTPSAreWebLinks() {
        for link in ["http://example.com", "https://example.com/a?b=c", "HTTPS://EXAMPLE.COM"] {
            XCTAssertTrue(URL(string: link)!.isWebLink, link)
        }
        for link in ["file:///etc/passwd", "ssh://host", "smb://server/share", "javascript:alert(1)",
                     "discord://discord.com/channels/1", "x-apple.systempreferences:com.apple"] {
            XCTAssertFalse(URL(string: link)!.isWebLink, link)
        }
    }

    // MARK: - Join from clipboard

    func testClipboardMeetingLinkOpensAsMeeting() {
        guard case let .openMeetingLink(link) = ClipboardLink.action(for: "https://meet.google.com/abc-defg-hij") else {
            return XCTFail("Expected a meeting link")
        }
        XCTAssertEqual(link.service, .meet)
    }

    func testClipboardWebPageOpensInBrowser() {
        XCTAssertEqual(
            ClipboardLink.action(for: "https://example.com/agenda"),
            .openWebURL(URL(string: "https://example.com/agenda")!)
        )
    }

    /// Copying a link often picks up surrounding whitespace or a newline.
    func testClipboardLinkIsTrimmed() {
        XCTAssertEqual(
            ClipboardLink.action(for: "  https://example.com/agenda\n"),
            .openWebURL(URL(string: "https://example.com/agenda")!)
        )
    }

    func testClipboardRefusesOtherSchemes() {
        for content in ["file:///etc/passwd", "ssh://attacker.example", "smb://server/share",
                        "x-apple.systempreferences:com.apple.preference.security", "javascript:alert(1)"] {
            XCTAssertEqual(ClipboardLink.action(for: content), .invalid, content)
        }
    }

    func testClipboardTextThatIsNotALinkIsInvalid() {
        XCTAssertEqual(ClipboardLink.action(for: "see you at standup"), .invalid)
    }

    func testEmptyClipboard() {
        XCTAssertEqual(ClipboardLink.action(for: ""), .empty)
        XCTAssertEqual(ClipboardLink.action(for: " \n"), .empty)
    }

    // MARK: - Look-alike hosts

    func testDiscordLinksAreDetected() {
        for link in ["https://discord.com/channels/1/2", "https://discord.gg/abc123",
                     "https://canary.discord.com/channels/1/2", "https://discordapp.com/channels/1/2"] {
            XCTAssertEqual(detectMeetingLink(link)?.service, .discord, link)
        }
    }

    func testDiscordLookAlikeHostsAreNotDiscord() {
        for link in ["https://discord.evil.com/channels/1", "https://discord.phish/channels/1"] {
            XCTAssertNotEqual(detectMeetingLink(link)?.service, .discord, link)
        }
    }

    func testRingCentralLinksAreDetected() {
        for link in ["https://ringcentral.com/join/123", "https://v.ringcentral.com/join/123",
                     "https://meetings.eu.ringcentral.com/j/123"] {
            XCTAssertEqual(detectMeetingLink(link)?.service, .ringcentral, link)
        }
    }

    func testRingCentralLookAlikeHostsAreNotRingCentral() {
        for link in ["https://evilringcentral.com/join/123", "https://ringcentral.com.evil.net/join/123"] {
            XCTAssertNotEqual(detectMeetingLink(link)?.service, .ringcentral, link)
        }
    }
}
