//
//  ProviderHealth.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 24.04.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//
import Foundation

public struct ProviderHealth: Equatable {
    public var lastSuccessfulRefresh: Date?
    public var lastAttemptedRefresh: Date?
    public var lastErrorDescription: String?
    /// True when the displayed data comes from a preserved snapshot, not the latest fetch attempt.
    public var isStale: Bool
    public var authRequired: Bool
    /// True when macOS calendar access is missing (see `EventKitAccessError`),
    /// so the UI can ask for it instead of offering a refresh.
    public var permissionRequired: Bool

    public init(
        lastSuccessfulRefresh: Date? = nil,
        lastAttemptedRefresh: Date? = nil,
        lastErrorDescription: String? = nil,
        isStale: Bool = false,
        authRequired: Bool = false,
        permissionRequired: Bool = false
    ) {
        self.lastSuccessfulRefresh = lastSuccessfulRefresh
        self.lastAttemptedRefresh = lastAttemptedRefresh
        self.lastErrorDescription = lastErrorDescription
        self.isStale = isStale
        self.authRequired = authRequired
        self.permissionRequired = permissionRequired
    }
}

extension ProviderHealth {
    static func success(attempted: Date) -> ProviderHealth {
        ProviderHealth(
            lastSuccessfulRefresh: attempted,
            lastAttemptedRefresh: attempted,
            lastErrorDescription: nil,
            isStale: false,
            authRequired: false
        )
    }

    static func failure(
        previous: ProviderHealth,
        attempted: Date,
        error: Error
    ) -> ProviderHealth {
        ProviderHealth(
            lastSuccessfulRefresh: previous.lastSuccessfulRefresh,
            lastAttemptedRefresh: attempted,
            lastErrorDescription: Self.errorDescription(error),
            isStale: true,
            authRequired: Self.isAuthRequired(error),
            permissionRequired: Self.isPermissionRequired(error)
        )
    }

    private static func isPermissionRequired(_ error: Error) -> Bool {
        switch error {
        case let CalendarSyncError.calendarAccessFailed(underlying),
             let CalendarSyncError.eventFetchFailed(underlying):
            return isPermissionRequired(underlying)
        default:
            return error is EventKitAccessError
        }
    }

    private static func errorDescription(_ error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        return error.localizedDescription
    }

    private static func isAuthRequired(_ error: Error) -> Bool {
        if let authError = error as? AuthError {
            switch authError {
            case .notSignedIn:
                return true
            case .cancelled, .refreshFailed:
                return false
            }
        }

        if let googleError = error as? GoogleCalendarError {
            switch googleError {
            case .unauthorized:
                return true
            case .forbiddenCalendar, .httpStatus, .missingItems:
                return false
            }
        }

        switch error {
        case let CalendarSyncError.calendarAccessFailed(underlying):
            return isAuthRequired(underlying)
        case let CalendarSyncError.eventFetchFailed(underlying):
            return isAuthRequired(underlying)
        default:
            return false
        }
    }
}
