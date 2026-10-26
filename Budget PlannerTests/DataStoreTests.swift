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
                           occurredAt: .now, note: "Lunch")

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
                           occurredAt: .now, note: nil, repeatMonthly: true)

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
                           occurredAt: .now, note: nil)

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

    // MARK: Activity query

    /// Inserts `count` expenses in the current month, one minute apart.
    private func insertMonthExpenses(context: ModelContext, count: Int) throws -> [UUID] {
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let category = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        var ids: [UUID] = []
        for i in 0..<count {
            let tx = Transaction(
                kind: .expense, amount: 1,
                occurredAt: monthStart.addingTimeInterval(Double(i + 1) * 60),
                timeZoneID: TimeZone.current.identifier,
                wallet: wallet, category: category,
                createdAt: monthStart.addingTimeInterval(Double(i))
            )
            context.insert(tx)
            ids.append(tx.id)
        }
        try context.save()
        return ids
    }

    @Test("Cursor paging yields every record once, even when one is inserted mid-paging")
    func cursorPagingNoDuplicatesOrGaps() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let originalIDs = try insertMonthExpenses(context: context, count: 120)

        let query = ActivityQuery(context: context)
        let filters = ActivityFilters(month: .now)
        var cursor: TransactionCursor?
        var collected: [UUID] = []

        while true {
            let page = try query.page(filters: filters, matchedCategoryIDs: [], after: cursor, limit: 50)
            if page.isEmpty { break }
            collected.append(contentsOf: page.map(\.id))
            let last = page[page.count - 1]
            cursor = TransactionCursor(occurredAt: last.occurredAt, createdAt: last.createdAt)

            // After the first page, insert a brand-new newest record.
            if collected.count == 50 {
                let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
                let cal = Calendar.current
                let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
                context.insert(Transaction(kind: .expense, amount: 1,
                                           occurredAt: monthStart.addingTimeInterval(200 * 60),
                                           timeZoneID: TimeZone.current.identifier, wallet: wallet))
                try context.save()
            }
            if page.count < 50 { break }
        }

        #expect(collected.count == 120)                 // no gaps
        #expect(Set(collected).count == 120)             // no duplicates
        #expect(Set(originalIDs).isSubset(of: Set(collected)))
    }

    @Test("Kind filter returns only that kind")
    func kindFilter() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let service = TransactionService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let expenseCat = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)
        let incomeCat = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .income).first)
        try service.create(kind: .expense, amount: 10, category: expenseCat, wallet: wallet, occurredAt: .now, note: nil)
        try service.create(kind: .income, amount: 20, category: incomeCat, wallet: wallet, occurredAt: .now, note: nil)

        let query = ActivityQuery(context: context)
        let incomeOnly = try query.page(filters: ActivityFilters(month: .now, kind: .income), matchedCategoryIDs: [], after: nil)
        #expect(incomeOnly.allSatisfy { $0.kind == .income })
        #expect(incomeOnly.count == 1)
    }

    @Test("Day sections group records and carry the day's net total")
    func daySectionsAndTotals() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let tz = TimeZone.current.identifier
        let today = Date.now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        // Today: +100 income, -30 expense → net 70. Yesterday: -10 → net -10.
        context.insert(Transaction(kind: .income, amount: 100, occurredAt: today, timeZoneID: tz, wallet: wallet))
        context.insert(Transaction(kind: .expense, amount: 30, occurredAt: today, timeZoneID: tz, wallet: wallet))
        context.insert(Transaction(kind: .expense, amount: 10, occurredAt: yesterday, timeZoneID: tz, wallet: wallet))
        try context.save()

        let model = ActivityViewModel(context: context)
        #expect(model.sections.count == 2)
        #expect(model.sections.first?.net == 70)
        #expect(model.sections.last?.net == -10)
    }

    // MARK: Budget repository

    @Test("Create budget, look it up, and keep limit history")
    func budgetCrudAndHistory() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let repo = SwiftDataBudgetRepository(context: context)
        let food = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)

        let octStart = utcDate(year: 2026, month: 10, day: 1)
        let budget = try repo.createBudget(category: food, limit: 400, effectiveFrom: octStart, alertAt80: true)
        #expect(try repo.budget(forCategoryID: food.id)?.id == budget.id)
        #expect((budget.limits ?? []).count == 1)

        // New limit for a later period keeps the old one (history).
        let decStart = utcDate(year: 2026, month: 12, day: 1)
        try repo.setLimit(budget, amount: 500, effectiveFrom: decStart)
        #expect((budget.limits ?? []).count == 2)
        #expect(BudgetService.limit(from: budget.limits ?? [], periodStart: octStart) == 400)
        #expect(BudgetService.limit(from: budget.limits ?? [], periodStart: decStart) == 500)

        // Editing the same period updates in place (no new history entry).
        try repo.setLimit(budget, amount: 450, effectiveFrom: octStart)
        #expect((budget.limits ?? []).count == 2)
        #expect(BudgetService.limit(from: budget.limits ?? [], periodStart: octStart) == 450)

        try repo.archive(budget)
        #expect(try repo.activeBudgets().isEmpty)
    }

    @Test("Deleting a budget frees its category")
    func deleteBudgetFreesCategory() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let repo = SwiftDataBudgetRepository(context: context)
        let food = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)
        let budget = try repo.createBudget(category: food, limit: 300, effectiveFrom: .now, alertAt80: true)
        #expect(try repo.budget(forCategoryID: food.id)?.id == budget.id)

        try repo.delete(budget)
        #expect(try repo.budget(forCategoryID: food.id) == nil)
        #expect(try repo.activeBudgets().isEmpty)
    }

    // MARK: Goals

    @Test("Deposit and withdraw adjust the goal's saved amount")
    func goalDepositWithdraw() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let service = GoalService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)

        let goal = try service.createGoal(name: "Trip", iconName: "airplane", target: 1000, targetDate: nil,
                                          reminder: false, startingAmount: 0, sourceWallet: nil)
        _ = try service.deposit(goal, amount: 100, wallet: wallet)
        try service.withdraw(goal, amount: 30, wallet: wallet)
        #expect(GoalMath.saved(for: goal) == dec("70"))
    }

    @Test("A deposit that reaches the target reports completion and marks the goal")
    func goalCompletion() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let service = GoalService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)

        let goal = try service.createGoal(name: "Phone", iconName: "target", target: 100, targetDate: nil,
                                          reminder: false, startingAmount: 0, sourceWallet: nil)
        let completed = try service.deposit(goal, amount: 100, wallet: wallet)
        #expect(completed)
        #expect(goal.status == .completed)
    }

    @Test("Spend from goal reduces the goal and the wallet, and is excluded from its budget")
    func spendFromGoal() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let goalService = GoalService(context: context)
        let txService = TransactionService(context: context)
        let wallet = try #require(try SwiftDataWalletRepository(context: context).activeWallets().first)
        let food = try #require(try SwiftDataCategoryRepository(context: context).activeCategories(kind: .expense).first)
        wallet.openingBalance = 500

        let goal = try goalService.createGoal(name: "Trip", iconName: "airplane", target: 300, targetDate: nil,
                                              reminder: false, startingAmount: 150, sourceWallet: wallet)
        try txService.create(kind: .expense, amount: 100, category: food, wallet: wallet,
                             occurredAt: .now, note: nil, paidFromGoal: goal)

        // Goal drops by 100 (150 deposit − 100 spend).
        #expect(GoalMath.saved(for: goal) == dec("50"))

        let allTx = try SwiftDataTransactionRepository(context: context).allTransactions()
        // Wallet (Total) drops by 100.
        #expect(BalanceService.walletBalance(wallet, transactions: allTx) == dec("400"))

        // The goal-paid expense is excluded from the category budget.
        let period = PeriodCalculator.period(for: .now, startDay: 1, timeZoneID: TimeZone.current.identifier)
        #expect(BudgetService.spent(categoryID: food.id, period: period, transactions: allTx) == dec("0"))
    }

    // MARK: Category management

    @Test("createCustom adds a fetchable custom category")
    func createCustomCategory() throws {
        let container = try makeContainer()
        let repo = SwiftDataCategoryRepository(context: container.mainContext)
        let c = try repo.createCustom(kind: .expense, name: "  Coffee  ", iconName: "cup.and.saucer.fill")
        #expect(c.defaultKey == nil)
        #expect(c.customName == "Coffee")               // trimmed
        #expect(c.iconName == "cup.and.saucer.fill")
        #expect(try repo.activeCategories(kind: .expense).contains { $0.id == c.id })
    }

    @Test("Deleting a custom category soft-deletes it and its budget")
    func deleteCustomWithBudget() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let catRepo = SwiftDataCategoryRepository(context: context)
        let budgetRepo = SwiftDataBudgetRepository(context: context)

        let c = try catRepo.createCustom(kind: .expense, name: "Coffee", iconName: "cup.and.saucer.fill")
        let period = PeriodCalculator.period(for: .now, startDay: 1, timeZoneID: TimeZone.current.identifier)
        try budgetRepo.createBudget(category: c, limit: dec("50"), effectiveFrom: period.start, alertAt80: true)
        #expect(try budgetRepo.activeBudgets().count == 1)

        try catRepo.deleteCustom(c)
        #expect(c.deletedAt != nil)
        #expect(try catRepo.activeCategories(kind: .expense).isEmpty)
        // The budget is cleaned up too, so Plan shows no orphan.
        #expect(try budgetRepo.activeBudgets().isEmpty)
    }

    @Test("Deleting a default category is prevented")
    func defaultCategoryProtected() throws {
        let container = try seededContainer()
        let repo = SwiftDataCategoryRepository(context: container.mainContext)
        let food = try #require(try repo.activeCategories(kind: .expense).first { $0.defaultKey != nil })

        try repo.deleteCustom(food)   // no-op for defaults
        #expect(food.deletedAt == nil)
        #expect(try repo.activeCategories(kind: .expense).contains { $0.id == food.id })
    }
}
