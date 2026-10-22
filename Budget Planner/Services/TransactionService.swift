//
//  TransactionService.swift
//  Pocket Ledger
//
//  Creates, edits and soft-deletes transactions. When an income is marked
//  "repeat monthly" it also creates a RecurringRule. Returns a summary used by
//  the saved-confirmation card.
//

import Foundation
import SwiftData

@MainActor
struct TransactionService {
    let context: ModelContext

    struct SavedSummary {
        let amount: Decimal
        let kind: TransactionKind
        let categoryName: String
        let walletName: String
    }

    /// Creates a transaction (and, for repeating income, a RecurringRule).
    @discardableResult
    func create(
        kind: TransactionKind,
        amount: Decimal,
        category: Category,
        wallet: Wallet,
        occurredAt: Date,
        note: String?,
        paidFromGoal: Goal? = nil,
        repeatMonthly: Bool = false
    ) throws -> SavedSummary {
        let timeZoneID = TimeZone.current.identifier
        let transaction = Transaction(
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            timeZoneID: timeZoneID,
            note: note?.isEmpty == true ? nil : note,
            wallet: wallet,
            category: category,
            paidFromGoal: paidFromGoal
        )
        context.insert(transaction)

        // Paying an expense from a goal also draws the goal down (reduces its
        // saved amount): reduces Total and the goal, Available unchanged.
        if let goal = paidFromGoal, kind == .expense {
            let spend = GoalEntry(kind: .spend, amount: amount, occurredAt: occurredAt,
                                  timeZoneID: timeZoneID, goal: goal, wallet: wallet)
            context.insert(spend)
            goal.entries = (goal.entries ?? []) + [spend]
        }

        if kind == .income, repeatMonthly {
            let dayOfMonth = Calendar.current.component(.day, from: occurredAt)
            let rule = RecurringRule(
                kind: .income,
                amount: amount,
                note: transaction.note,
                frequency: .monthly,
                dayOfMonth: dayOfMonth,
                nextOccurrence: RecurringSchedule.nextMonthlyDate(after: occurredAt, dayOfMonth: dayOfMonth),
                isActive: true,
                wallet: wallet,
                category: category
            )
            context.insert(rule)
            transaction.recurringRule = rule
        }

        try context.save()
        return summary(for: transaction)
    }

    /// Updates an existing transaction's editable fields.
    @discardableResult
    func update(
        _ transaction: Transaction,
        kind: TransactionKind,
        amount: Decimal,
        category: Category,
        wallet: Wallet,
        occurredAt: Date,
        note: String?
    ) throws -> SavedSummary {
        transaction.kind = kind
        transaction.amount = amount
        transaction.category = category
        transaction.wallet = wallet
        transaction.occurredAt = occurredAt
        transaction.note = note?.isEmpty == true ? nil : note
        transaction.updatedAt = .now
        try context.save()
        return summary(for: transaction)
    }

    /// Soft-deletes a transaction (recoverable).
    func delete(_ transaction: Transaction) throws {
        transaction.deletedAt = .now
        transaction.updatedAt = .now
        try context.save()
    }

    private func summary(for transaction: Transaction) -> SavedSummary {
        SavedSummary(
            amount: transaction.amount,
            kind: transaction.kind,
            categoryName: transaction.category?.displayName ?? "",
            walletName: transaction.wallet?.name ?? ""
        )
    }
}
