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
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query private var settingsList: [AppSettings]

    @State private var monthOffset = 0
    @State private var showEdit = false
    @State private var showAddExpense = false

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
        .safeAreaInset(edge: .bottom) { addExpenseBar }
        .navigationTitle(budget.category?.displayName ?? "Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) { AddEditBudgetView(editingBudget: budget) }
        .sheet(isPresented: $showAddExpense) {
            AddTransactionView(context: context, presetCategoryID: budget.category?.id)
        }
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
            HStack(alignment: .firstTextBaseline) {
                Text("\(stats.remaining.formatted(.currency(code: currencyCode))) left")
                    .font(.title.weight(.bold)).foregroundStyle(stats.isOver100 ? Theme.expense : Theme.text)
                Spacer()
                Text("\(stats.spent.formatted(.currency(code: currencyCode))) of \(stats.limit.formatted(.currency(code: currencyCode))) · \(Int((stats.fraction * 100).rounded()))%")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            ProgressBar(fraction: stats.fraction,
                        color: stats.isOver100 ? Theme.expense : (stats.isOver80 ? Theme.warning : Theme.primary))
            if monthOffset == 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To stay under").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("\(BudgetService.perDayAllowance(remaining: stats.remaining, period: period, asOf: .now, timeZoneID: tzID).formatted(.currency(code: currencyCode))) / day")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("At this pace").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("~\(BudgetService.paceProjection(spent: stats.spent, period: period, asOf: .now, timeZoneID: tzID).formatted(.currency(code: currencyCode)))")
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
                    TransactionRow(transaction: tx, currencyCode: currencyCode)
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

    private var addExpenseBar: some View {
        Button { showAddExpense = true } label: {
            Label("Add expense", systemImage: "plus")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity).frame(height: 50)
                .foregroundStyle(.white)
                .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}
