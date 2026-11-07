//
//  RefreshTimeout.swift
//  MeetingBarTests
//

import Foundation

/// Upper bound for waiting on a `CalendarSync` refresh. An expectation ends
/// as soon as it's met, so this only matters on a slow machine: the first
/// fetch goes through a 200 ms throttle and a main-actor task, and on a busy
/// CI runner that took over a second (`ThisWeekFetchTests`, 2026-11-05).
let refreshTimeout: TimeInterval = 10
