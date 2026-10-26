//
//  SeedService.swift
//  Pocket Ledger
//
//  First-launch seeding. Creates the default wallets, categories and an
//  AppSettings record if the store is empty. Idempotent: it seeds wallets and
//  categories only when none exist, so running it on every launch is safe.
//

import Foundation
import SwiftData

enum SeedService {
    /// Seeds defaults if needed. Returns true if wallets/categories were seeded.
    @discardableResult
    @MainActor
    static func seedIfNeeded(context: ModelContext) throws -> Bool {
        // Always ensure a settings record exists.
        var settingsDescriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        settingsDescriptor.fetchLimit = 1
        if try context.fetch(settingsDescriptor).isEmpty {
            context.insert(AppSettings())
        }

        // Keep built-in category icons in sync with DefaultData, so changing a
        // default icon takes effect for existing installs too. Custom categories
        // (no defaultKey) are left untouched.
        try reconcileDefaultIcons(context: context)

        let walletCount = try context.fetchCount(
            FetchDescriptor<Wallet>(predicate: #Predicate { $0.deletedAt == nil })
        )
        guard walletCount == 0 else {
            try context.save()
            return false
        }

        for (index, def) in DefaultData.wallets.enumerated() {
            let wallet = Wallet(
                name: NSLocalizedString(def.nameKey, comment: "default wallet name"),
                type: def.type,
                openingBalance: 0,
                sortOrder: index
            )
            context.insert(wallet)
        }

        for (index, def) in DefaultData.allCategories.enumerated() {
            let category = Category(
                kind: def.kind,
                defaultKey: def.key,
                iconName: def.icon,
                sortOrder: index
            )
            context.insert(category)
        }

        try context.save()
        return true
    }

    /// Updates existing default categories' icons to match `DefaultData` when a
    /// built-in icon changes. Only touches categories with a `defaultKey`.
    @MainActor
    private static func reconcileDefaultIcons(context: ModelContext) throws {
        let defaultIcons = Dictionary(
            uniqueKeysWithValues: DefaultData.allCategories.map { ($0.key, $0.icon) }
        )
        let categories = try context.fetch(
            FetchDescriptor<Category>(predicate: #Predicate { $0.deletedAt == nil })
        )
        for category in categories {
            guard let key = category.defaultKey, let icon = defaultIcons[key], category.iconName != icon else { continue }
            category.iconName = icon
            category.updatedAt = .now
        }
    }
}
