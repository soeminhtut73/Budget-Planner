//
//  Budget.swift
//  Pocket Ledger
//
//  A budget is a spending limit, not money. It never holds or deducts money;
//  it only measures expenses in its category during the current period.
//  Its "spent" amount is never stored — it is always calculated from records.
//

import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID = UUID()
    var alertAt80: Bool = true
    var isArchived: Bool = false

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var category: Category?

    /// Limit history: each entry has an `effectiveFrom` period start.
    @Relationship(deleteRule: .cascade, inverse: \BudgetLimit.budget)
    var limits: [BudgetLimit]?

    init(
        id: UUID = UUID(),
        alertAt80: Bool = true,
        isArchived: Bool = false,
        category: Category? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.alertAt80 = alertAt80
        self.isArchived = isArchived
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
