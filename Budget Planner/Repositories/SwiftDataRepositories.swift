//
//  SwiftDataRepositories.swift
//  Pocket Ledger
//
//  SwiftData-backed implementations of the repository protocols.
//

import Foundation
import SwiftData

struct SwiftDataWalletRepository: WalletRepository {
    let context: ModelContext

    func activeWallets() throws -> [Wallet] {
        var descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func allWallets() throws -> [Wallet] {
        let descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func wallet(id: UUID) throws -> Wallet? {
        var descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ wallet: Wallet) { context.insert(wallet) }

    func softDelete(_ wallet: Wallet) {
        wallet.deletedAt = .now
        wallet.updatedAt = .now
    }

    func save() throws { try context.save() }
}

struct SwiftDataTransactionRepository: TransactionRepository {
    let context: ModelContext

    func allTransactions() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func transaction(id: UUID) throws -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ transaction: Transaction) { context.insert(transaction) }

    func softDelete(_ transaction: Transaction) {
        transaction.deletedAt = .now
        transaction.updatedAt = .now
    }

    func save() throws { try context.save() }
}

struct SwiftDataCategoryRepository: CategoryRepository {
    let context: ModelContext

    func activeCategories(kind: CategoryKind) throws -> [Category] {
        // Kind is an enum; filter it in memory to avoid enum-in-#Predicate limits.
        try allCategories()
            .filter { $0.kind == kind && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func allCategories() throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    func category(id: UUID) throws -> Category? {
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ category: Category) { context.insert(category) }

    func softDelete(_ category: Category) {
        category.deletedAt = .now
        category.updatedAt = .now
    }

    func save() throws { try context.save() }
}

struct SwiftDataRecurringRuleRepository: RecurringRuleRepository {
    let context: ModelContext

    func activeRules() throws -> [RecurringRule] {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isActive == true },
            sortBy: [SortDescriptor(\.nextOccurrence)]
        )
        return try context.fetch(descriptor)
    }

    func allRules() throws -> [RecurringRule] {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.nextOccurrence)]
        )
        return try context.fetch(descriptor)
    }

    func rule(id: UUID) throws -> RecurringRule? {
        var descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ rule: RecurringRule) { context.insert(rule) }

    func softDelete(_ rule: RecurringRule) {
        rule.deletedAt = .now
        rule.updatedAt = .now
    }

    func save() throws { try context.save() }
}

struct SwiftDataAppSettingsRepository: AppSettingsRepository {
    let context: ModelContext

    func current() throws -> AppSettings? {
        var descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func ensureDefault() throws -> AppSettings {
        if let existing = try current() { return existing }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    func save() throws { try context.save() }
}

struct SwiftDataBudgetRepository: BudgetRepository {
    let context: ModelContext

    func activeBudgets() throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isArchived == false },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func budget(forCategoryID id: UUID) throws -> Budget? {
        try activeBudgets().first { $0.category?.id == id }
    }

    @discardableResult
    func createBudget(category: Category, limit: Decimal, effectiveFrom: Date, alertAt80: Bool) throws -> Budget {
        let budget = Budget(alertAt80: alertAt80, category: category)
        context.insert(budget)
        let budgetLimit = BudgetLimit(amount: limit, effectiveFrom: effectiveFrom, budget: budget)
        context.insert(budgetLimit)
        budget.limits = [budgetLimit]
        try context.save()
        return budget
    }

    func setLimit(_ budget: Budget, amount: Decimal, effectiveFrom: Date) throws {
        if let existing = (budget.limits ?? []).first(where: {
            $0.deletedAt == nil && Calendar.current.isDate($0.effectiveFrom, inSameDayAs: effectiveFrom)
        }) {
            existing.amount = amount
            existing.updatedAt = .now
        } else {
            let newLimit = BudgetLimit(amount: amount, effectiveFrom: effectiveFrom, budget: budget)
            context.insert(newLimit)
            budget.limits = (budget.limits ?? []) + [newLimit]
        }
        budget.updatedAt = .now
        try context.save()
    }

    func archive(_ budget: Budget) throws {
        budget.isArchived = true
        budget.updatedAt = .now
        try context.save()
    }

    func save() throws { try context.save() }
}

struct SwiftDataGoalRepository: GoalRepository {
    let context: ModelContext

    func activeGoals() throws -> [Goal] {
        // Status is an enum; filter it in memory to avoid enum-in-#Predicate
        // limitations. Goals are few, so this is cheap.
        try allGoals().filter { $0.status == .active }
    }

    func allGoals() throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func goal(id: UUID) throws -> Goal? {
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ goal: Goal) { context.insert(goal) }

    func softDelete(_ goal: Goal) {
        goal.deletedAt = .now
        goal.updatedAt = .now
    }

    func save() throws { try context.save() }
}
