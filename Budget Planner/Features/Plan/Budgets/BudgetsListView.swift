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
    @Environment(\.money) private var money

    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil && $0.isArchived == false }, sort: \Budget.createdAt)
    private var budgets: [Budget]
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query private var settingsList: [AppSettings]

    @State private var editingBudget: Budget?
    @State private var pendingDelete: Budget?

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
            }
            .padding(.bottom, 96)
        }
        .navigationDestination(for: Budget.self) { budget in
            BudgetDetailView(budget: budget)
        }
        .sheet(item: $editingBudget) { budget in
            AddEditBudgetView(editingBudget: budget)
        }
        .confirmationDialog(
            "Delete this budget?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete budget", role: .destructive) {
                if let budget = pendingDelete {
                    try? SwiftDataBudgetRepository(context: context).delete(budget)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Your records stay; only the spending limit is removed.")
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
                Text("\(money.string(left)) left")
                    .font(.title.weight(.bold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(money.string(totalSpent)) of \(money.string(totalLimit))")
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
                    .contextMenu {
                        Button { editingBudget = pair.budget } label: { Label("Edit budget", systemImage: "pencil") }
                        Button(role: .destructive) { pendingDelete = pair.budget } label: {
                            Label("Delete budget", systemImage: "trash")
                        }
                    }
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
                Text("\(money.string(stats.spent)) / \(money.string(stats.limit))")
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
            Text(money.string(outside)).foregroundStyle(Theme.text)
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
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
