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
}
