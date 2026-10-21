//
//  RecurringRule.swift
//  Pocket Ledger
//
//  A template that posts a transaction on a schedule (monthly in V1), e.g.
//  a salary that repeats each month. Posting logic lives in RecurringService.
//

import Foundation
import SwiftData

@Model
final class RecurringRule {
    var id: UUID = UUID()
    var kind: TransactionKind = TransactionKind.income
    var amount: Decimal = 0
    var note: String?
    var frequency: Frequency = Frequency.monthly
    /// 1...31; clamped to the last day of short months when posting.
    var dayOfMonth: Int = 1
    var nextOccurrence: Date = Date.now
    var isActive: Bool = true

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var wallet: Wallet?
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.recurringRule)
    var transactions: [Transaction]?

    init(
        id: UUID = UUID(),
        kind: TransactionKind = .income,
        amount: Decimal = 0,
        note: String? = nil,
        frequency: Frequency = .monthly,
        dayOfMonth: Int = 1,
        nextOccurrence: Date = .now,
        isActive: Bool = true,
        wallet: Wallet? = nil,
        category: Category? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.note = note
        self.frequency = frequency
        self.dayOfMonth = dayOfMonth
        self.nextOccurrence = nextOccurrence
        self.isActive = isActive
        self.wallet = wallet
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
