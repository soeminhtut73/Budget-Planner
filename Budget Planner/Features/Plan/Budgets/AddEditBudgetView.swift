//
//  AddEditBudgetView.swift
//  Pocket Ledger
//
//  Create or edit a budget: pick a category (ones that already have a budget
//  are disabled), set a monthly limit, toggle the 80% alert. Shows a recent
//  average hint and a this-month preview. A budget never changes any balance.
//

import SwiftUI
import SwiftData

struct AddEditBudgetView: View {
    var editingBudget: Budget?

    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Category> { $0.deletedAt == nil && $0.isArchived == false }, sort: \Category.sortOrder)
    private var categories: [Category]
    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil && $0.isArchived == false })
    private var budgets: [Budget]
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query private var settingsList: [AppSettings]

    @State private var selectedCategory: Category?
    @State private var amount: AmountInput
    @State private var alertAt80 = true
    @State private var didInit = false

    init(editingBudget: Budget? = nil) {
        self.editingBudget = editingBudget
        _amount = State(initialValue: AmountInput(minorUnits: 2))
    }

    private var settings: AppSettings? { settingsList.first }
    private var currencyCode: String { settings?.mainCurrency ?? "USD" }
    private var startDay: Int { settings?.budgetStartDay ?? 1 }
    private var period: BudgetPeriod {
        PeriodCalculator.period(for: .now, startDay: startDay, timeZoneID: TimeZone.current.identifier)
    }
    private var expenseCategories: [Category] { categories.filter { $0.kind == .expense } }
    private var budgetedCategoryIDs: Set<UUID> {
        Set(budgets.filter { $0.id != editingBudget?.id }.compactMap { $0.category?.id })
    }
    private var canSave: Bool { selectedCategory != nil && amount.value > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if editingBudget == nil {
                        categoryGrid
                    } else if let category = selectedCategory {
                        HStack { CategoryLabel(category: category).font(.title3.weight(.semibold)); Spacer() }
                    }
                    limitSection
                    settingsCard
                    previewCard
                    Text("A budget is a spending limit, not money. Expenses still come out of your wallets.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                    NumberPad(allowsDecimal: money.minorUnits > 0) { handleKey($0) }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(editingBudget == nil ? "Add budget" : "Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
            .onAppear(perform: initializeIfNeeded)
        }
    }

    // MARK: Sections

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(expenseCategories) { category in
                    let taken = budgetedCategoryIDs.contains(category.id)
                    let selected = selectedCategory?.id == category.id
                    Button {
                        if !taken { selectedCategory = category }
                    } label: {
                        VStack(spacing: 4) {
                            CategoryIcon(systemName: category.iconName, size: 28)
                            CategoryLabel(category: category)
                                .font(.caption2).lineLimit(1)
                                .foregroundStyle(taken ? Theme.secondaryText : Theme.text)
                            if taken { Image(systemName: "checkmark").font(.caption2).foregroundStyle(Theme.secondaryText) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? Theme.primary : Theme.border, style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: taken ? [4] : [])))
                    }
                    .buttonStyle(.plain)
                    .disabled(taken)
                }
            }
            Text("Checked categories already have a budget").font(.caption2).foregroundStyle(Theme.secondaryText)
        }
    }

    private var limitSection: some View {
        VStack(spacing: 2) {
            Text("Monthly limit · \(money.currencyCode)").font(.footnote).foregroundStyle(Theme.secondaryText)
            AmountText(amount: amount.value, style: .neutral,
                       tint: amount.value == 0 ? Theme.secondaryText : nil)
                .font(.system(size: 40, weight: .bold))
            if let category = selectedCategory {
                let avg = recentMonthlyAverage(categoryID: category.id)
                if avg > 0 {
                    Text("You spent about \(money.string(avg))/month recently")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private var settingsCard: some View {
        Toggle("Alert at 80%", isOn: $alertAt80)
            .tint(Theme.primary)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var previewCard: some View {
        let spent = selectedCategory.map { BudgetService.spent(categoryID: $0.id, period: period, transactions: transactions) } ?? 0
        let newLimit = amount.value
        let oldTotal = budgets.reduce(Decimal(0)) { $0 + (BudgetService.limit(from: $1.limits ?? [], periodStart: period.start) ?? 0) }
        let editingOld = editingBudget.map { BudgetService.limit(from: $0.limits ?? [], periodStart: period.start) ?? 0 } ?? 0
        let newTotal = oldTotal - editingOld + newLimit
        return VStack(alignment: .leading, spacing: 8) {
            Text("THIS MONTH").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            HStack {
                Text("Already spent").foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(money.string(spent)) of \(money.string(newLimit))")
                    .fontWeight(.semibold).foregroundStyle(Theme.text)
            }
            ProgressBar(fraction: BudgetService.fraction(spent: spent, limit: newLimit))
            HStack {
                Text("All budgets").foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(money.string(oldTotal)) → \(money.string(newTotal))")
                    .foregroundStyle(Theme.text)
            }
            HStack {
                Text("Total balance").foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("No change").fontWeight(.semibold).foregroundStyle(Theme.text)
            }
        }
        .font(.subheadline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.border.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Logic

    private func initializeIfNeeded() {
        guard !didInit else { return }
        didInit = true
        if let editingBudget {
            selectedCategory = editingBudget.category
            let limit = BudgetService.limit(from: editingBudget.limits ?? [], periodStart: period.start) ?? 0
            amount = AmountInput.from(limit, minorUnits: money.minorUnits)
            alertAt80 = editingBudget.alertAt80
        } else {
            amount = AmountInput(minorUnits: money.minorUnits)
        }
    }

    private func handleKey(_ key: NumberPadKey) {
        switch key {
        case .digit(let d): amount.tapDigit(d)
        case .dot: amount.tapDot()
        case .delete: amount.tapDelete()
        }
    }

    private func recentMonthlyAverage(categoryID: UUID) -> Decimal {
        let tz = TimeZone.current.identifier
        var refDate = period.start.addingTimeInterval(-1)   // step into the previous period
        var total: Decimal = 0
        for _ in 0..<3 {
            let p = PeriodCalculator.period(for: refDate, startDay: startDay, timeZoneID: tz)
            total += BudgetService.spent(categoryID: categoryID, period: p, transactions: transactions)
            refDate = p.start.addingTimeInterval(-1)
        }
        return total / 3
    }

    private func save() {
        guard let category = selectedCategory else { return }
        let repo = SwiftDataBudgetRepository(context: context)
        do {
            if let editingBudget {
                editingBudget.alertAt80 = alertAt80
                try repo.setLimit(editingBudget, amount: amount.value, effectiveFrom: period.start)
            } else {
                try repo.createBudget(category: category, limit: amount.value, effectiveFrom: period.start, alertAt80: alertAt80)
            }
            Task { await NotificationService.requestAuthorization() }
            dismiss()
        } catch {
            assertionFailure("Save budget failed: \(error)")
        }
    }
}
