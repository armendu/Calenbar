//
//  MeetingLinkHardeningTests.swift
//  MeetingBarLogicTests
//
//  Calendar event fields are attacker-controlled: anyone can send an invite.
//  These pin down what such an invite can make the app open.
//

import XCTest

@testable import MeetingBarLogic

final class MeetingLinkHardeningTests: XCTestCase {
    // MARK: - Event URL field

    private func action(forEventURL string: String) -> MeetingOpeningAction {
        MeetingOpeningPolicy.action(
            for: MeetingOpeningEvent(title: "Invite", meetingLink: nil, eventURL: URL(string: string)!),
            runJoinEventScript: false
        )
    }

    func testWebEventURLIsOpened() {
        XCTAssertEqual(action(forEventURL: "https://example.com/e"), .openEventURL(URL(string: "https://example.com/e")!))
        XCTAssertEqual(action(forEventURL: "http://example.com/e"), .openEventURL(URL(string: "http://example.com/e")!))
    }

    func testSchemeCheckIgnoresCase() {
        XCTAssertEqual(action(forEventURL: "HTTPS://example.com/e"), .openEventURL(URL(string: "HTTPS://example.com/e")!))
    }

    func testNonWebEventURLIsNotOpened() {
        for url in [
            "ssh://attacker.example",
            "vnc://attacker.example",
            "smb://attacker.example/share",
            "file:///Applications/Calculator.app",
            "shortcuts://run-shortcut?name=Anything",
            "vscode://file/tmp/x"
        ] {
            XCTAssertEqual(action(forEventURL: url), .notifyMissingLink(title: "Invite"), url)
        }
    }

    // MARK: - Lookalike domains

    private func detect(_ text: String, email: String? = "me@example.com") -> MeetingLink? {
        MeetingLinkDetector.detect(
            location: text, eventURL: nil, notes: nil,
            calendarEmail: email, currentUserEmail: email
        )
    }

    func testGenuineLinksStillDetected() {
        XCTAssertEqual(detect("https://meet.google.com/abc-defg-hij")?.service, .meet)
        XCTAssertEqual(detect("https://app.gather.town/app/abc/def?spawnToken=1")?.service, .gather)
        XCTAssertEqual(detect("https://app.cal.com/video/abc123")?.service, .calcom)
    }

    func testLookalikeMeetDomainIsNotTreatedAsGoogleMeet() {
        for url in ["https://meet-google.com/abc-defg-hij", "https://meetxgoogle.com/abc-defg-hij"] {
            XCTAssertNil(detect(url), url)
        }
    }

    func testLookalikeGatherAndCalDomainsAreNotDetected() {
        XCTAssertNil(detect("https://appxgather.town/app/abc/def?spawnToken=1"))
        XCTAssertNil(detect("https://app.gatherxtown/app/abc/def?spawnToken=1"))
        XCTAssertNil(detect("https://appxcal.com/video/abc123"))
    }

    func testMeetLinksGetTheAccountEmailOnlyOnGoogleMeet() throws {
        let genuine = try XCTUnwrap(detect("https://meet.google.com/abc-defg-hij"))
        XCTAssertTrue(genuine.url.absoluteString.contains("authuser="))
        XCTAssertNil(detect("https://meet-google.com/abc-defg-hij"))
    }

    /// Guards every built-in pattern: an unescaped `.` in a host name matches
    /// any character, so `meet.google.com` would also match `meet-google.com`.
    func testBuiltInPatternsEscapeDotsInHostNames() throws {
        let unescapedHostDot = try NSRegularExpression(pattern: #"(?<!\\)(?<=[A-Za-z0-9])\.(?=[A-Za-z0-9])"#)
        for provider in MeetingProvider.all {
            guard let pattern = provider.regexPattern else { continue }
            let range = NSRange(pattern.startIndex..., in: pattern)
            XCTAssertNil(unescapedHostDot.firstMatch(in: pattern, range: range), "\(provider.id): \(pattern)")
        }
    }
}
