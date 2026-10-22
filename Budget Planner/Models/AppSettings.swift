//
//  AppSettings.swift
//  Pocket Ledger
//
//  A single settings record for the app. `mainCurrency` is an ISO 4217 code
//  (V1: one currency for the whole app). `budgetStartDay` is 1...28.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()
    /// ISO 4217 code, e.g. "USD", "MMK", "VND", "SGD".
    var mainCurrency: String = "USD"
    /// BCP-47 language code, e.g. "en", "my".
    var language: String = "en"
    /// Day of month the budget period starts on (1...28).
    var budgetStartDay: Int = 1
    /// Whether the user has picked a currency in onboarding (existing installs
    /// default to false so they see the currency step once).
    var currencyChosen: Bool = false

    var notifyBudgetAlerts: Bool = true
    var notifyGoalReminders: Bool = true
    var notifyRecurringPosted: Bool = true
    var faceIDLock: Bool = false

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        mainCurrency: String = "USD",
        language: String = "en",
        budgetStartDay: Int = 1,
        currencyChosen: Bool = false,
        notifyBudgetAlerts: Bool = true,
        notifyGoalReminders: Bool = true,
        notifyRecurringPosted: Bool = true,
        faceIDLock: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.mainCurrency = mainCurrency
        self.language = language
        self.budgetStartDay = budgetStartDay
        self.currencyChosen = currencyChosen
        self.notifyBudgetAlerts = notifyBudgetAlerts
        self.notifyGoalReminders = notifyGoalReminders
        self.notifyRecurringPosted = notifyRecurringPosted
        self.faceIDLock = faceIDLock
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
