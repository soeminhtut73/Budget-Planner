//
//  DataStoreTests.swift
//  Budget PlannerTests
//
//  All SwiftData-backed tests live here in ONE serialized suite. Swift Testing
//  runs tests in parallel by default, and concurrently creating several
//  in-memory ModelContainers crashes the runtime — serializing keeps exactly
//  one container live at a time. Each test keeps a strong reference to its
//  container for the duration of the test body.
//

import Testing
import Foundation
import SwiftData
@testable import Budget_Planner

@MainActor
@Suite("Data store", .serialized)
struct DataStoreTests {

    private func makeContainer() throws -> ModelContainer {
        try AppSchema.makeContainer(inMemory: true)
    }

    // MARK: Soft delete

    @Test("Inserted wallet is fetched; soft delete hides it from reads")
    func softDeleteWallet() throws {
        let container = try makeContainer()
        let repo = SwiftDataWalletRepository(context: container.mainContext)
        let wallet = Wallet(name: "Cash", openingBalance: dec("100"))
        repo.insert(wallet)
        try repo.save()
        #expect(try repo.activeWallets().count == 1)

        repo.softDelete(wallet)
        try repo.save()
        #expect(wallet.deletedAt != nil)
        #expect(try repo.activeWallets().isEmpty)
        #expect(try repo.allWallets().isEmpty)
    }

    @Test("Archived wallets are excluded from activeWallets but kept in allWallets")
    func archivedWalletFiltering() throws {
        let container = try makeContainer()
        let repo = SwiftDataWalletRepository(context: container.mainContext)
        repo.insert(Wallet(name: "Cash"))
        repo.insert(Wallet(name: "Old", isArchived: true))
        try repo.save()
        #expect(try repo.activeWallets().map(\.name) == ["Cash"])
        #expect(try repo.allWallets().count == 2)
    }

    @Test("Goal status filtering: activeGoals excludes archived")
    func goalStatusFiltering() throws {
        let container = try makeContainer()
        let repo = SwiftDataGoalRepository(context: container.mainContext)
        repo.insert(Goal(name: "Trip", status: .active))
        repo.insert(Goal(name: "Done", status: .archived))
        try repo.save()
        #expect(try repo.activeGoals().map(\.name) == ["Trip"])
        #expect(try repo.allGoals().count == 2)
    }

    // MARK: Seeding

    @Test("First-launch seeding creates default wallets, categories and settings")
    func seedsDefaults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        #expect(try SeedService.seedIfNeeded(context: context))

        #expect(try context.fetchCount(FetchDescriptor<Wallet>()) == 3)
        let categories = try context.fetch(FetchDescriptor<Budget_Planner.Category>())
        #expect(categories.filter { $0.kind == .expense }.count == 8)
        #expect(categories.filter { $0.kind == .income }.count == 5)
        #expect(try context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    @Test("Seeding is idempotent — a second run changes nothing")
    func seedingIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        #expect(try SeedService.seedIfNeeded(context: context) == true)
        #expect(try SeedService.seedIfNeeded(context: context) == false)
        #expect(try context.fetchCount(FetchDescriptor<Wallet>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Budget_Planner.Category>()) == 13)
        #expect(try context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    // MARK: Sample data

    @Test("Sample data generates the requested count, spread over ~6 months")
    func sampleDataSpread() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SampleData.generate(context: context, count: 500)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        #expect(txs.count == 500)

        let now = Date.now
        let earliest = txs.map(\.occurredAt).min() ?? now
        let latest = txs.map(\.occurredAt).max() ?? now
        #expect(earliest >= now.addingTimeInterval(-181 * 86_400))
        #expect(latest <= now)
        #expect(earliest <= now.addingTimeInterval(-120 * 86_400))
    }

    @Test("Sample data is deterministic for a fixed seed")
    func sampleDataDeterministic() throws {
        let c1 = try makeContainer()
        let c2 = try makeContainer()
        try SampleData.generate(context: c1.mainContext, count: 50, seed: 7)
        try SampleData.generate(context: c2.mainContext, count: 50, seed: 7)
        let a = try c1.mainContext.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.occurredAt)])).map(\.amount)
        let b = try c2.mainContext.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.occurredAt)])).map(\.amount)
        #expect(a == b)
    }

    // MARK: Category repository

    @Test("activeCategories filters by kind and excludes soft-deleted")
    func categoryFiltering() throws {
        let container = try makeContainer()
        let repo = SwiftDataCategoryRepository(context: container.mainContext)
        try SeedService.seedIfNeeded(context: container.mainContext)

        let expense = try repo.activeCategories(kind: .expense)
        #expect(expense.count == 8)
        #expect(try repo.activeCategories(kind: .income).count == 5)
        #expect(expense.map(\.sortOrder) == expense.map(\.sortOrder).sorted())

        if let first = expense.first {
            repo.softDelete(first)
            try repo.save()
            #expect(try repo.activeCategories(kind: .expense).count == 7)
        }
    }

    // MARK: Transaction service

    /// Returns a seeded container. Tests must keep the returned container alive
    /// for the duration of the test (the main context alone does not retain it).
    private func seededContainer() throws -> ModelContainer {
        let container = try makeContainer()
        try SeedService.seedIfNeeded(context: container.mainContext)
        return container
    }

    @Test("Creating an expense inserts it and reduces the wallet balance")
    func createExpense() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let service = TransactionService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let category = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)
        wallet.openingBalance = 100

        try service.create(kind: .expense, amount: dec("12.50"), category: category, wallet: wallet,
                           occurredAt: .now, note: "Lunch", currencyCode: "USD")

        let txs = try SwiftDataTransactionRepository(context: context).allTransactions()
        #expect(txs.count == 1)
        #expect(BalanceService.walletBalance(wallet, transactions: txs) == dec("87.50"))
    }

    @Test("Repeating income creates a RecurringRule with a future next date")
    func createRepeatingIncome() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let service = TransactionService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let category = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .income).first)

        try service.create(kind: .income, amount: dec("3000"), category: category, wallet: wallet,
                           occurredAt: .now, note: nil, repeatMonthly: true, currencyCode: "USD")

        let rules = try SwiftDataRecurringRuleRepository(context: context).activeRules()
        #expect(rules.count == 1)
        #expect(rules.first?.nextOccurrence ?? .distantPast > .now)
    }

    @Test("Deleting a transaction soft-deletes it")
    func deleteTransaction() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let service = TransactionService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let category = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)
        try service.create(kind: .expense, amount: dec("5"), category: category, wallet: wallet,
                           occurredAt: .now, note: nil, currencyCode: "USD")

        let repo = SwiftDataTransactionRepository(context: context)
        let tx = try #require(try repo.allTransactions().first)
        try service.delete(tx)
        #expect(try repo.allTransactions().isEmpty)
        #expect(tx.deletedAt != nil)
    }

    @Test("postDueRules posts overdue occurrences and advances the rule")
    func postsDueRecurring() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let category = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .income).first)

        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now
        let rule = RecurringRule(kind: .income, amount: 1000, frequency: .monthly, dayOfMonth: 15,
                                 nextOccurrence: twoMonthsAgo, isActive: true, wallet: wallet, category: category)
        context.insert(rule)
        try context.save()

        let created = try RecurringService.postDueRules(context: context, asOf: .now)
        #expect(created.count >= 2)
        #expect(rule.nextOccurrence > .now)
    }
}
