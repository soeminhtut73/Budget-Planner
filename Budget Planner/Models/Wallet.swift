//
//  Wallet.swift
//  Pocket Ledger
//

import Foundation
import SwiftData

@Model
final class Wallet {
    var id: UUID = UUID()
    var name: String = ""
    var type: WalletType = WalletType.cash
    var openingBalance: Decimal = 0
    var sortOrder: Int = 0
    var isArchived: Bool = false

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// Soft delete: non-nil means hidden/recoverable; hard-delete only when purging.
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.wallet)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \GoalEntry.wallet)
    var goalEntries: [GoalEntry]?

    init(
        id: UUID = UUID(),
        name: String = "",
        type: WalletType = .cash,
        openingBalance: Decimal = 0,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.openingBalance = openingBalance
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
