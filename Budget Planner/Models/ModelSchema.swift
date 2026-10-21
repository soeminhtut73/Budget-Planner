//
//  ModelSchema.swift
//  Pocket Ledger
//
//  The single list of persisted model types and helpers to build a
//  ModelContainer. Tests build an in-memory container from the same schema.
//

import Foundation
import SwiftData

enum AppSchema {
    /// Every @Model type the app persists. Keep this list complete so the
    /// schema (and a future CloudKit store) stays in sync with the models.
    static let models: [any PersistentModel.Type] = [
        Wallet.self,
        Category.self,
        Transaction.self,
        RecurringRule.self,
        Budget.self,
        BudgetLimit.self,
        Goal.self,
        GoalEntry.self,
        AppSettings.self,
    ]

    static var schema: Schema { Schema(models) }

    /// Builds a container. `inMemory` is used by tests and previews.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
