//
//  Transaction.swift
//  Pocket Ledger
//
//  Amount is always stored as a positive Decimal; `kind` decides the sign.
//  `occurredAt` is UTC and `timeZoneID` is the user's zone at that moment —
//  which day/month a record belongs to is always decided in its local zone.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var kind: TransactionKind = TransactionKind.expense
    /// Always > 0; the sign comes from `kind`.
    var amount: Decimal = 0
    var occurredAt: Date = Date.now
    var timeZoneID: String = TimeZone.current.identifier
    var note: String?

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var wallet: Wallet?
    var category: Category?
    /// Set when this expense was paid from a goal (reduces Total and the goal;
    /// excluded from budget totals).
    var paidFromGoal: Goal?
    /// Set when this transaction was created by a recurring rule.
    var recurringRule: RecurringRule?

    init(
        id: UUID = UUID(),
        kind: TransactionKind = .expense,
        amount: Decimal = 0,
        occurredAt: Date = .now,
        timeZoneID: String = TimeZone.current.identifier,
        note: String? = nil,
        wallet: Wallet? = nil,
        category: Category? = nil,
        paidFromGoal: Goal? = nil,
        recurringRule: RecurringRule? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.occurredAt = occurredAt
        self.timeZoneID = timeZoneID
        self.note = note
        self.wallet = wallet
        self.category = category
        self.paidFromGoal = paidFromGoal
        self.recurringRule = recurringRule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
