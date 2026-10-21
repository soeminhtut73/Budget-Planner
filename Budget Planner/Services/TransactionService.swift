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
        let currencyCode: String
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
        repeatMonthly: Bool = false,
        currencyCode: String
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
        return summary(for: transaction, currencyCode: currencyCode)
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
        note: String?,
        currencyCode: String
    ) throws -> SavedSummary {
        transaction.kind = kind
        transaction.amount = amount
        transaction.category = category
        transaction.wallet = wallet
        transaction.occurredAt = occurredAt
        transaction.note = note?.isEmpty == true ? nil : note
        transaction.updatedAt = .now
        try context.save()
        return summary(for: transaction, currencyCode: currencyCode)
    }

    /// Soft-deletes a transaction (recoverable).
    func delete(_ transaction: Transaction) throws {
        transaction.deletedAt = .now
        transaction.updatedAt = .now
        try context.save()
    }

    private func summary(for transaction: Transaction, currencyCode: String) -> SavedSummary {
        SavedSummary(
            amount: transaction.amount,
            kind: transaction.kind,
            categoryName: transaction.category?.displayName ?? "",
            walletName: transaction.wallet?.name ?? "",
            currencyCode: currencyCode
        )
    }
}
