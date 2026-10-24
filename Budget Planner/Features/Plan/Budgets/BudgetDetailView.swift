//
//  BudgetDetailView.swift
//  Pocket Ledger
//
//  One budget: month switcher, left/spent/%, per-day allowance and pace (for
//  the current month), that category's records, and shortcuts to Activity and
//  to add an expense.
//

import SwiftUI
import SwiftData

struct BudgetDetailView: View {
    let budget: Budget

    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query private var settingsList: [AppSettings]

    @Environment(\.dismiss) private var dismiss
    @State private var monthOffset = 0
    @State private var showEdit = false
    @State private var showAddExpense = false
    @State private var showDeleteConfirm = false
    /// A local mascot for this page, driven by this budget's remaining limit —
    /// separate from the app-wide (balance-driven) mascot on Home.
    @State private var detailMascot = MascotController()

    private var settings: AppSettings? { settingsList.first }
    private var currencyCode: String { settings?.mainCurrency ?? "USD" }
    private var startDay: Int { settings?.budgetStartDay ?? 1 }
    private var tzID: String { TimeZone.current.identifier }

    private var refDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
    }
    private var period: BudgetPeriod {
        PeriodCalculator.period(for: refDate, startDay: startDay, timeZoneID: tzID)
    }
    private var stats: BudgetStats {
        BudgetService.stats(for: budget, period: period, transactions: transactions)
    }
    private var records: [Transaction] {
        guard let categoryID = budget.category?.id else { return [] }
        let filters = ActivityFilters(month: refDate, categoryID: categoryID)
        return (try? ActivityQuery(context: context).allMatching(filters: filters, matchedCategoryIDs: [])) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthSwitcher
                summaryCard
                recordsCard
            }
            .padding()
            .padding(.bottom, 90)
        }
        .background(Theme.background)
        .onAppear { detailMascot.setOverLimit(stats.isOver100) }
        .onChange(of: stats.isOver100) { _, over in detailMascot.setOverLimit(over) }
        .overlay(alignment: .bottomTrailing) { addExpenseButton }
        .navigationTitle(budget.category?.displayName ?? "Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button { showEdit = true } label: { Label("Edit budget", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete budget", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) { AddEditBudgetView(editingBudget: budget) }
        .sheet(isPresented: $showAddExpense) {
            AddTransactionView(context: context, presetCategoryID: budget.category?.id)
        }
        .confirmationDialog("Delete this budget?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete budget", role: .destructive) { deleteBudget() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your records stay; only the spending limit is removed.")
        }
    }

    private func deleteBudget() {
        try? SwiftDataBudgetRepository(context: context).delete(budget)
        dismiss()
    }

    private var monthSwitcher: some View {
        HStack {
            Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(period.start, format: .dateTime.month(.wide).year()).font(.headline)
            Spacer()
            Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                .disabled(monthOffset >= 0)
        }
        .foregroundStyle(Theme.text)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(money.string(stats.remaining))
                    .font(.title.weight(.bold)).foregroundStyle(stats.isOver100 ? Theme.expense : Theme.text)
                Spacer()
                // Mascot reflects this budget's remaining limit: sad when over.
                MascotView(controller: detailMascot, size: 64)
            }
            ProgressBar(fraction: stats.fraction,
                        color: stats.isOver100 ? Theme.expense : (stats.isOver80 ? Theme.warning : Theme.primary))
            if monthOffset == 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To stay under").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("\(money.string(BudgetService.perDayAllowance(remaining: stats.remaining, period: period, asOf: .now, timeZoneID: tzID))) / day")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("At this pace").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("~\(money.string(BudgetService.paceProjection(spent: stats.spent, period: period, asOf: .now, timeZoneID: tzID)))")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECORDS · \(records.count) THIS MONTH").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            if records.isEmpty {
                Text("No records this month").foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(Array(records.prefix(5).enumerated()), id: \.element.id) { index, tx in
                    TransactionRow(transaction: tx)
                    if index < min(records.count, 5) - 1 { Divider() }
                }
                if let categoryID = budget.category?.id {
                    NavigationLink {
                        ActivityView(context: context, initialCategoryID: categoryID)
                    } label: {
                        Text("See all \(records.count) in Activity")
                            .font(.subheadline).foregroundStyle(Theme.primary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var addExpenseButton: some View {
        Button { showAddExpense = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.primary, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel("Add expense")
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}
