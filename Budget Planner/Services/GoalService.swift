//
//  GoalService.swift
//  Pocket Ledger
//
//  Creates goals and records deposits/withdrawals as GoalEntries. Goals reserve
//  money; they don't move it — a deposit never changes a wallet or Total
//  balance, only the goal's saved amount (and therefore Available). Deciding
//  which mascot reaction to play (v1.1) or whether to show the completion sheet
//  is the view model's job; this service just reports `didComplete`.
//

import Foundation
import SwiftData

@MainActor
struct GoalService {
    let context: ModelContext

    @discardableResult
    func createGoal(
        name: String,
        iconName: String,
        target: Decimal,
        targetDate: Date?,
        reminder: Bool,
        startingAmount: Decimal,
        sourceWallet: Wallet?
    ) throws -> Goal {
        let goal = Goal(
            name: name,
            iconName: iconName,
            targetAmount: target,
            targetDate: targetDate,
            reminderEnabled: reminder,
            status: .active
        )
        context.insert(goal)
        if startingAmount > 0 {
            let entry = GoalEntry(kind: .deposit, amount: startingAmount, goal: goal, wallet: sourceWallet)
            context.insert(entry)
            goal.entries = [entry]
        }
        try context.save()
        if reminder {
            Task { await NotificationService.scheduleGoalReminder(goalID: goal.id, name: name) }
        }
        return goal
    }

    /// Records a deposit. Returns true if it brought the goal to its target.
    @discardableResult
    func deposit(_ goal: Goal, amount: Decimal, wallet: Wallet?, occurredAt: Date = .now) throws -> Bool {
        let entry = GoalEntry(kind: .deposit, amount: amount, occurredAt: occurredAt, goal: goal, wallet: wallet)
        context.insert(entry)
        goal.entries = (goal.entries ?? []) + [entry]
        goal.updatedAt = .now

        let saved = GoalMath.saved(for: goal)
        let complete = GoalMath.isComplete(saved: saved, target: goal.targetAmount)
        if complete, goal.status == .active { goal.status = .completed }
        try context.save()
        return complete
    }

    func withdraw(_ goal: Goal, amount: Decimal, wallet: Wallet?, occurredAt: Date = .now) throws {
        let entry = GoalEntry(kind: .withdraw, amount: amount, occurredAt: occurredAt, goal: goal, wallet: wallet)
        context.insert(entry)
        goal.entries = (goal.entries ?? []) + [entry]
        goal.updatedAt = .now
        try context.save()
    }

    func update(_ goal: Goal, name: String, iconName: String, target: Decimal, targetDate: Date?, reminder: Bool) throws {
        let wasReminder = goal.reminderEnabled
        goal.name = name
        goal.iconName = iconName
        goal.targetAmount = target
        goal.targetDate = targetDate
        goal.reminderEnabled = reminder
        goal.updatedAt = .now
        try context.save()

        if reminder, !wasReminder {
            Task { await NotificationService.scheduleGoalReminder(goalID: goal.id, name: name) }
        } else if !reminder, wasReminder {
            NotificationService.cancelGoalReminder(goalID: goal.id)
        }
    }

    func archive(_ goal: Goal) throws {
        goal.status = .archived
        goal.updatedAt = .now
        try context.save()
        NotificationService.cancelGoalReminder(goalID: goal.id)
    }

    func delete(_ goal: Goal) throws {
        goal.deletedAt = .now
        goal.updatedAt = .now
        try context.save()
        NotificationService.cancelGoalReminder(goalID: goal.id)
    }
}
