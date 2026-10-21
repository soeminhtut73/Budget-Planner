//
//  Goal.swift
//  Pocket Ledger
//
//  Goals reserve money; they don't move it. Saved = deposits − withdrawals −
//  amounts paid from the goal. Adding to a goal does not change Total balance.
//

import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "target"
    var targetAmount: Decimal = 0
    var targetDate: Date?
    var reminderEnabled: Bool = false
    var status: GoalStatus = GoalStatus.active

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \GoalEntry.goal)
    var entries: [GoalEntry]?

    /// Expenses marked as paid from this goal.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.paidFromGoal)
    var paidExpenses: [Transaction]?

    init(
        id: UUID = UUID(),
        name: String = "",
        iconName: String = "target",
        targetAmount: Decimal = 0,
        targetDate: Date? = nil,
        reminderEnabled: Bool = false,
        status: GoalStatus = .active,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.reminderEnabled = reminderEnabled
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
