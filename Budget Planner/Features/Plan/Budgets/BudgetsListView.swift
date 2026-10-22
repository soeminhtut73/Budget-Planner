//
//  BudgetsListView.swift
//  Pocket Ledger
//
//  Plan → Budgets: period summary, one row per budget (progress + 80% chip),
//  "Spent outside budgets" line, and Add budget. Budgets are limits, not money.
//

import SwiftUI
import SwiftData

struct BudgetsListView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil && $0.isArchived == false }, sort: \Budget.createdAt)
    private var budgets: [Budget]
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query private var settingsList: [AppSettings]

    @State private var showAdd = false

    private var settings: AppSettings? { settingsList.first }
    private var currencyCode: String { settings?.mainCurrency ?? "USD" }
    private var startDay: Int { settings?.budgetStartDay ?? 1 }
    private var period: BudgetPeriod {
        PeriodCalculator.period(for: .now, startDay: startDay, timeZoneID: TimeZone.current.identifier)
    }

    private var statsByBudget: [(budget: Budget, stats: BudgetStats)] {
        budgets.map { ($0, BudgetService.stats(for: $0, period: period, transactions: transactions)) }
    }
    private var totalLimit: Decimal { statsByBudget.reduce(0) { $0 + $1.stats.limit } }
    private var totalSpent: Decimal { statsByBudget.reduce(0) { $0 + $1.stats.spent } }
    private var outside: Decimal {
        let ids = Set(budgets.compactMap { $0.category?.id })
        return BudgetService.spentOutsideBudgets(period: period, transactions: transactions, budgetedCategoryIDs: ids)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if budgets.isEmpty {
                    emptyState
                } else {
                    periodSummary
                    budgetRows
                    outsideLine
                }
                addButton
            }
            .padding(.bottom, 96)
        }
        .navigationDestination(for: Budget.self) { budget in
            BudgetDetailView(budget: budget)
        }
        .sheet(isPresented: $showAdd) {
            AddEditBudgetView()
        }
    }

    private var periodSummary: some View {
        let left = totalLimit - totalSpent
        let daysLeft = BudgetService.daysLeft(period: period, asOf: .now, timeZoneID: TimeZone.current.identifier)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(period.start, format: .dateTime.month(.wide)).textCase(.uppercase)
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Text("budget").textCase(.uppercase)
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(daysLeft) days left").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(left.formatted(.currency(code: currencyCode))) left")
                    .font(.title.weight(.bold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(totalSpent.formatted(.currency(code: currencyCode))) of \(totalLimit.formatted(.currency(code: currencyCode)))")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            ProgressBar(fraction: BudgetService.fraction(spent: totalSpent, limit: totalLimit),
                        color: left < 0 ? Theme.expense : Theme.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var budgetRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BY CATEGORY").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("Tap to see records").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            VStack(spacing: 0) {
                ForEach(Array(statsByBudget.enumerated()), id: \.element.budget.id) { index, pair in
                    NavigationLink(value: pair.budget) {
                        budgetRow(pair.budget, pair.stats)
                    }
                    .buttonStyle(.plain)
                    if index < statsByBudget.count - 1 { Divider() }
                }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func budgetRow(_ budget: Budget, _ stats: BudgetStats) -> some View {
        VStack(spacing: 6) {
            HStack {
                if let category = budget.category {
                    CategoryLabel(category: category).font(.headline).foregroundStyle(Theme.text)
                }
                if stats.isOver100 {
                    tag("Over budget", color: Theme.expense)
                } else if stats.isOver80 {
                    tag("Over 80%", color: Theme.warning)
                }
                Spacer()
                Text("\(stats.spent.formatted(.currency(code: currencyCode))) / \(stats.limit.formatted(.currency(code: currencyCode)))")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            ProgressBar(fraction: stats.fraction,
                        color: stats.isOver100 ? Theme.expense : (stats.isOver80 ? Theme.warning : Theme.primary))
        }
        .padding(.vertical, 8)
    }

    private func tag(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .foregroundStyle(color)
            .overlay(Capsule().stroke(color))
    }

    private var outsideLine: some View {
        HStack {
            Text("Spent outside budgets").foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(outside.formatted(.currency(code: currencyCode))).foregroundStyle(Theme.text)
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            Label("Add budget", systemImage: "plus")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity).frame(height: 50)
                .foregroundStyle(Theme.primary)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.primary, lineWidth: 1.5))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie").font(.system(size: 40)).foregroundStyle(Theme.secondaryText)
            Text("No budgets yet").font(.headline).foregroundStyle(Theme.text)
            Text("Set a monthly limit for a category to track it here.")
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
    }
}
