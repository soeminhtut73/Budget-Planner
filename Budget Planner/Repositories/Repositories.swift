//
//  Repositories.swift
//  Pocket Ledger
//
//  Data access goes through these protocols so a server-backed or synced
//  implementation (V2) can replace the local SwiftData one. Every read
//  excludes soft-deleted records (`deletedAt != nil`); deletes are soft.
//

import Foundation

protocol WalletRepository {
    /// Non-deleted, non-archived wallets, ordered by `sortOrder`.
    func activeWallets() throws -> [Wallet]
    /// All non-deleted wallets (including archived).
    func allWallets() throws -> [Wallet]
    func wallet(id: UUID) throws -> Wallet?
    func insert(_ wallet: Wallet)
    /// Soft delete: sets `deletedAt`; the record stays recoverable.
    func softDelete(_ wallet: Wallet)
    func save() throws
}

protocol TransactionRepository {
    /// All non-deleted transactions, newest first.
    func allTransactions() throws -> [Transaction]
    func transaction(id: UUID) throws -> Transaction?
    func insert(_ transaction: Transaction)
    func softDelete(_ transaction: Transaction)
    func save() throws
}

protocol CategoryRepository {
    /// Non-deleted, non-archived categories of a kind, ordered by `sortOrder`.
    func activeCategories(kind: CategoryKind) throws -> [Category]
    /// All non-deleted categories (both kinds, including archived).
    func allCategories() throws -> [Category]
    func category(id: UUID) throws -> Category?
    func insert(_ category: Category)
    func softDelete(_ category: Category)
    func save() throws
}

protocol RecurringRuleRepository {
    /// Non-deleted, active rules.
    func activeRules() throws -> [RecurringRule]
    /// All non-deleted rules.
    func allRules() throws -> [RecurringRule]
    func rule(id: UUID) throws -> RecurringRule?
    func insert(_ rule: RecurringRule)
    func softDelete(_ rule: RecurringRule)
    func save() throws
}

protocol AppSettingsRepository {
    /// The current settings record, if one exists.
    func current() throws -> AppSettings?
    /// Returns the existing settings or creates and persists defaults.
    func ensureDefault() throws -> AppSettings
    func save() throws
}

protocol BudgetRepository {
    /// Non-deleted, non-archived budgets.
    func activeBudgets() throws -> [Budget]
    func budget(forCategoryID id: UUID) throws -> Budget?
    /// Creates a budget for a category with its first limit.
    @discardableResult
    func createBudget(category: Category, limit: Decimal, effectiveFrom: Date, alertAt80: Bool) throws -> Budget
    /// Sets the limit for the given period start: updates an existing limit with
    /// that `effectiveFrom`, otherwise appends a new one (preserving history).
    func setLimit(_ budget: Budget, amount: Decimal, effectiveFrom: Date) throws
    func archive(_ budget: Budget) throws
    func save() throws
}

protocol GoalRepository {
    /// Non-deleted goals that are not archived.
    func activeGoals() throws -> [Goal]
    /// All non-deleted goals (including completed/archived).
    func allGoals() throws -> [Goal]
    func goal(id: UUID) throws -> Goal?
    func insert(_ goal: Goal)
    func softDelete(_ goal: Goal)
    func save() throws
}
