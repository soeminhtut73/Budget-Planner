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

    /// Schedules a repeating monthly reminder for a savings goal (1st, 10:00).
    /// A calendar trigger fires without background refresh.
    static func scheduleGoalReminder(goalID: UUID, name: String) async {
        await requestAuthorization()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Savings reminder")
        content.body = String(localized: "Time to add to \(name).")
        content.sound = .default

        var date = DateComponents()
        date.day = 1
        date.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID(goalID), content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelGoalReminder(goalID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID(goalID)])
    }

    private static func reminderID(_ goalID: UUID) -> String { "goal-\(goalID.uuidString)" }
}
