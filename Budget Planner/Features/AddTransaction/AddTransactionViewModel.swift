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

    // Fixed context
    let currencyCode: String
    let minorUnits: Int
    let mode: Mode

    private let context: ModelContext

    // Loaded reference data
    private(set) var expenseCategories: [Category] = []
    private(set) var incomeCategories: [Category] = []
    private(set) var wallets: [Wallet] = []

    init(context: ModelContext, editing: Transaction? = nil) {
        self.context = context

        let settings = try? SwiftDataAppSettingsRepository(context: context).ensureDefault()
        let code = settings?.mainCurrency ?? "USD"
        self.currencyCode = code
        self.minorUnits = CurrencyRounding.minorUnits(for: code)

        let categoryRepo = SwiftDataCategoryRepository(context: context)
        let walletRepo = SwiftDataWalletRepository(context: context)
        self.expenseCategories = (try? categoryRepo.activeCategories(kind: .expense)) ?? []
        self.incomeCategories = (try? categoryRepo.activeCategories(kind: .income)) ?? []
        self.wallets = (try? walletRepo.activeWallets()) ?? []

        if let tx = editing {
            self.mode = .edit(tx)
            self.kind = tx.kind
            self.amountInput = AmountInput.from(tx.amount, minorUnits: minorUnits)
            self.category = tx.category
            self.wallet = tx.wallet
            self.occurredAt = tx.occurredAt
            self.note = tx.note ?? ""
            self.repeatMonthly = tx.recurringRule != nil
        } else {
            self.mode = .create
            self.kind = .expense
            self.amountInput = AmountInput(minorUnits: minorUnits)
            self.occurredAt = .now
            self.category = expenseCategories.first
            self.wallet = wallets.first
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
            return try service.create(
                kind: kind,
                amount: amount,
                category: category,
                wallet: wallet,
                occurredAt: occurredAt,
                note: note,
                repeatMonthly: kind == .income && repeatMonthly,
                currencyCode: currencyCode
            )
        case .edit(let tx):
            return try service.update(
                tx,
                kind: kind,
                amount: amount,
                category: category,
                wallet: wallet,
                occurredAt: occurredAt,
                note: note,
                currencyCode: currencyCode
            )
        }
    }

    func delete() throws {
        if case .edit(let tx) = mode {
            try TransactionService(context: context).delete(tx)
        }
    }

    /// Resets amount and note for "Add another", keeping kind/wallet/category/date.
    func resetForAnother() {
        amountInput.clear()
        note = ""
    }
}
