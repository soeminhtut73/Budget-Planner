//
//  AddTransactionViewModel.swift
//  Pocket Ledger
//
//  State and logic for the Add / Edit transaction sheet. Views stay thin; all
//  saving, editing and preview math lives here and in the services it calls.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AddTransactionViewModel {
    enum Mode {
        case create
        case edit(Transaction)
    }

    struct BalancePreview {
        let walletBefore: Decimal
        let walletAfter: Decimal
        let totalBefore: Decimal
        let totalAfter: Decimal
    }

    // Editable state
    var kind: TransactionKind
    var amountInput: AmountInput
    var category: Category?
    var wallet: Wallet?
    var occurredAt: Date
    var note: String = ""
    var repeatMonthly: Bool = false
    /// Set when an expense is paid from a goal.
    var paidFromGoal: Goal?

    // Fixed context
    let money: MoneyFormatter
    let budgetStartDay: Int
    let mode: Mode

    /// Injected by the view once the environment is available; the view model
    /// drives mascot reactions (cashIn/cashOut) and the over-limit base mood.
    var mascot: MascotController?

    var currencyCode: String { money.currencyCode }
    var minorUnits: Int { money.minorUnits }

    private let context: ModelContext

    // Loaded reference data
    private(set) var expenseCategories: [Category] = []
    private(set) var incomeCategories: [Category] = []
    private(set) var wallets: [Wallet] = []
    /// Goals that can fund an expense (not archived).
    private(set) var goals: [Goal] = []

    init(context: ModelContext, editing: Transaction? = nil, presetCategoryID: UUID? = nil) {
        self.context = context

        let settings = try? SwiftDataAppSettingsRepository(context: context).ensureDefault()
        let code = settings?.mainCurrency ?? "USD"
        self.money = MoneyFormatter(currencyCode: code)
        let units = CurrencyInfo.minorUnits(for: code)
        self.budgetStartDay = settings?.budgetStartDay ?? 1

        let categoryRepo = SwiftDataCategoryRepository(context: context)
        let walletRepo = SwiftDataWalletRepository(context: context)
        let expense = (try? categoryRepo.activeCategories(kind: .expense)) ?? []
        let income = (try? categoryRepo.activeCategories(kind: .income)) ?? []
        let allWallets = (try? walletRepo.activeWallets()) ?? []
        let goalList = ((try? SwiftDataGoalRepository(context: context).allGoals()) ?? []).filter { $0.status != .archived }
        self.expenseCategories = expense
        self.incomeCategories = income
        self.wallets = allWallets
        self.goals = goalList

        if let tx = editing {
            self.mode = .edit(tx)
            self.kind = tx.kind
            self.amountInput = AmountInput.from(tx.amount, minorUnits: units)
            self.category = tx.category
            self.wallet = tx.wallet
            self.occurredAt = tx.occurredAt
            self.note = tx.note ?? ""
            self.repeatMonthly = tx.recurringRule != nil
            self.paidFromGoal = tx.paidFromGoal
        } else {
            self.mode = .create
            self.amountInput = AmountInput(minorUnits: units)
            self.occurredAt = .now
            self.wallet = allWallets.first
            if let presetCategoryID,
               let preset = (expense + income).first(where: { $0.id == presetCategoryID }) {
                self.kind = preset.kind == .income ? .income : .expense
                self.category = preset
            } else {
                self.kind = .expense
                self.category = expense.first
            }
        }
    }

    // MARK: Derived

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var amount: Decimal { amountInput.value }

    var canSave: Bool { amount > 0 && category != nil && wallet != nil }

    var categoriesForKind: [Category] {
        kind == .expense ? expenseCategories : incomeCategories
    }

    /// Income preview (create mode only), showing the effect on the wallet and Total.
    var incomePreview: BalancePreview? {
        guard case .create = mode, kind == .income, let wallet else { return nil }
        let txs = (try? SwiftDataTransactionRepository(context: context).allTransactions()) ?? []
        let walletBefore = BalanceService.walletBalance(wallet, transactions: txs)
        let totalBefore = BalanceService.totalBalance(wallets: wallets, transactions: txs)
        return BalancePreview(
            walletBefore: walletBefore,
            walletAfter: walletBefore + amount,
            totalBefore: totalBefore,
            totalAfter: totalBefore + amount
        )
    }

    // MARK: Mutations

    func handleKey(_ key: NumberPadKey) {
        switch key {
        case .digit(let d): amountInput.tapDigit(d)
        case .dot: amountInput.tapDot()
        case .delete: amountInput.tapDelete()
        }
    }

    /// Switches expense/income and keeps the selected category valid for the kind.
    func selectKind(_ newKind: TransactionKind) {
        guard newKind != kind else { return }
        kind = newKind
        if category == nil || category?.kind != categoryKind(for: newKind) {
            category = categoriesForKind.first
        }
        if newKind == .expense { repeatMonthly = false }
        if newKind == .income { paidFromGoal = nil }
    }

    private func categoryKind(for kind: TransactionKind) -> CategoryKind {
        kind == .income ? .income : .expense
    }

    /// Binding helper so the date picker changes only Y/M/D, keeping the time.
    func setDay(_ newDay: Date) {
        occurredAt = Self.combine(day: newDay, timeFrom: occurredAt)
    }

    static func combine(day: Date, timeFrom reference: Date) -> Date {
        let calendar = Calendar.current
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute, .second], from: reference)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute; c.second = t.second
        return calendar.date(from: c) ?? reference
    }

    /// Re-reads the category lists from the store (after one is created in the
    /// full New-category sheet) and optionally selects the new one.
    func reloadCategories(select category: Category? = nil) {
        let repo = SwiftDataCategoryRepository(context: context)
        expenseCategories = (try? repo.activeCategories(kind: .expense)) ?? []
        incomeCategories = (try? repo.activeCategories(kind: .income)) ?? []
        if let category {
            kind = category.kind == .income ? .income : .expense
            self.category = category
        }
    }

    @discardableResult
    func addCustomCategory(named name: String) -> Category? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sortOrder = (categoriesForKind.map(\.sortOrder).max() ?? 0) + 1
        let newCategory = Category(
            kind: categoryKind(for: kind),
            customName: trimmed,
            iconName: "tag",
            sortOrder: sortOrder
        )
        context.insert(newCategory)
        try? context.save()
        if kind == .expense { expenseCategories.append(newCategory) }
        else { incomeCategories.append(newCategory) }
        category = newCategory
        return newCategory
    }

    // MARK: Persistence

    func save() throws -> TransactionService.SavedSummary? {
        guard canSave, let category, let wallet else { return nil }
        let service = TransactionService(context: context)
        switch mode {
        case .create:
            let summary = try service.create(
                kind: kind,
                amount: amount,
                category: category,
                wallet: wallet,
                occurredAt: occurredAt,
                note: note,
                paidFromGoal: kind == .expense ? paidFromGoal : nil,
                repeatMonthly: kind == .income && repeatMonthly
            )
            if kind == .expense {
                scheduleBudgetAlertIfNeeded(category: category, addedAmount: amount, occurredAt: occurredAt)
            }
            // Reaction after a successful save only (never on failure/cancel).
            mascot?.play(kind == .income ? .cashIn : .cashOut)
            refreshMascotMood()
            return summary
        case .edit(let tx):
            let summary = try service.update(
                tx,
                kind: kind,
                amount: amount,
                category: category,
                wallet: wallet,
                occurredAt: occurredAt,
                note: note
            )
            refreshMascotMood()
            return summary
        }
    }

    func delete() throws {
        if case .edit(let tx) = mode {
            try TransactionService(context: context).delete(tx)
            refreshMascotMood()
        }
    }

    /// Updates the mascot's base mood from the main (total) balance — sad when
    /// it goes negative. Called after every change that affects the balance.
    private func refreshMascotMood() {
        guard let mascot else { return }
        let wallets = (try? SwiftDataWalletRepository(context: context).activeWallets()) ?? []
        let txs = (try? SwiftDataTransactionRepository(context: context).allTransactions()) ?? []
        let total = BalanceService.totalBalance(wallets: wallets, transactions: txs)
        mascot.setOverLimit(total < 0)
    }

    /// Fires a local notification if this expense crossed 80% or 100% of its
    /// category budget for the expense's period. The view model decides to
    /// notify; the budget math is in BudgetService.
    private func scheduleBudgetAlertIfNeeded(category: Category, addedAmount: Decimal, occurredAt: Date) {
        let budgetRepo = SwiftDataBudgetRepository(context: context)
        guard let budget = try? budgetRepo.budget(forCategoryID: category.id) else { return }

        let tzID = TimeZone.current.identifier
        let period = PeriodCalculator.period(for: occurredAt, startDay: budgetStartDay, timeZoneID: tzID)
        guard period.contains(occurredAt) else { return }

        let allTx = (try? SwiftDataTransactionRepository(context: context).allTransactions()) ?? []
        let newSpent = BudgetService.spent(categoryID: category.id, period: period, transactions: allTx)
        let priorSpent = newSpent - addedAmount
        let limit = BudgetService.limit(from: budget.limits ?? [], periodStart: period.start) ?? 0
        guard limit > 0 else { return }

        let name = category.displayName

        if BudgetService.crossedThreshold(1.0, priorSpent: priorSpent, newSpent: newSpent, limit: limit) {
            let title = String(localized: "Budget reached")
            let body = String(localized: "You've reached your \(name) budget.")
            Task { await NotificationService.fire(title: title, body: body) }
        } else if budget.alertAt80,
                  BudgetService.crossedThreshold(0.8, priorSpent: priorSpent, newSpent: newSpent, limit: limit) {
            let remaining = BudgetService.remaining(limit: limit, spent: newSpent)
            let title = String(localized: "Budget alert")
            let body = String(localized: "You've used over 80% of your \(name) budget — \(money.string(remaining)) left.")
            Task { await NotificationService.fire(title: title, body: body) }
        }
    }

    /// Resets amount and note for "Add another", keeping kind/wallet/category/date.
    func resetForAnother() {
        amountInput.clear()
        note = ""
    }
}
