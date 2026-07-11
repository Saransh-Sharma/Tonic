//
//  NotificationDelegate.swift
//  Tonic
//
//  Makes Tonic's notifications actionable. Before this delegate existed,
//  clicking a notification did nothing. Now categories carry actions that
//  deep-link into the right screen via the existing navigation notifications.
//

import AppKit
import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationDelegate()

    // Category identifiers.
    static let maintenanceDoneCategory = "TONIC_MAINTENANCE_DONE"
    static let updatesAvailableCategory = "TONIC_UPDATES_AVAILABLE"

    // Action identifiers.
    private static let reviewAction = "TONIC_REVIEW_CLEANUP"
    private static let openAppsAction = "TONIC_OPEN_APPS"

    /// Install the delegate and register actionable categories. Call once at launch.
    func install() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let maintenance = UNNotificationCategory(
            identifier: Self.maintenanceDoneCategory,
            actions: [
                UNNotificationAction(
                    identifier: Self.reviewAction,
                    title: "Review",
                    options: [.foreground]
                ),
            ],
            intentIdentifiers: []
        )
        let updates = UNNotificationCategory(
            identifier: Self.updatesAvailableCategory,
            actions: [
                UNNotificationAction(
                    identifier: Self.openAppsAction,
                    title: "Open Apps",
                    options: [.foreground]
                ),
            ],
            intentIdentifiers: []
        )
        center.setNotificationCategories([maintenance, updates])
    }

    // Show banners even while Tonic is frontmost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let category = response.notification.request.content.categoryIdentifier

        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            switch category {
            case Self.maintenanceDoneCategory:
                // Review what was cleaned: Clean › History.
                NotificationCenter.default.post(
                    name: .navigateToDestination,
                    object: nil,
                    userInfo: ["destination": NavigationDestination.recentlyCleaned.rawValue]
                )
            case Self.updatesAvailableCategory:
                NotificationCenter.default.post(
                    name: .navigateToDestination,
                    object: nil,
                    userInfo: ["destination": NavigationDestination.appManager.rawValue]
                )
            default:
                break
            }
        }
    }
}
