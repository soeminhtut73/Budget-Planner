//
//  Category.swift
//  Pocket Ledger
//
//  Default categories are identified by `defaultKey` and localized through
//  the String Catalog, so they translate. Custom categories store the name
//  the user typed in `customName`.
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var kind: CategoryKind = CategoryKind.expense
    /// e.g. "food"; nil for a user-created category.
    var defaultKey: String?
    /// The name the user typed; nil for a default category.
    var customName: String?
    var iconName: String = "tag"
    var sortOrder: Int = 0
    var isArchived: Bool = false

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    /// At most one active budget per category.
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budget: Budget?

    init(
        id: UUID = UUID(),
        kind: CategoryKind = .expense,
        defaultKey: String? = nil,
        customName: String? = nil,
        iconName: String = "tag",
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.defaultKey = defaultKey
        self.customName = customName
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
