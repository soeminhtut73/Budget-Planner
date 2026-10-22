//
//  NotificationService.swift
//  Pocket Ledger
//
//  Local notifications for budget alerts. Authorization is requested when the
//  user first creates a budget; alerts fire immediately when a saved expense
//  crosses 80% or 100% of its budget.
//

import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Fires an immediate local notification if the app is authorized.
    static func fire(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
