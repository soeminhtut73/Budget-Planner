//
//  BudgetLimit.swift
//  Pocket Ledger
//
//  One monthly limit value, effective from a given period start. Reports for a
//  past month use the limit that was active then; editing applies from the
//  current period onward (a new BudgetLimit with a later `effectiveFrom`).
//

import Foundation
import SwiftData

@Model
final class BudgetLimit {
    var id: UUID = UUID()
    var amount: Decimal = 0
    /// Calendar date (period start) this limit takes effect from.
    var effectiveFrom: Date = Date.now

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var budget: Budget?

    init(
        id: UUID = UUID(),
        amount: Decimal = 0,
        effectiveFrom: Date = .now,
        budget: Budget? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.effectiveFrom = effectiveFrom
        self.budget = budget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
