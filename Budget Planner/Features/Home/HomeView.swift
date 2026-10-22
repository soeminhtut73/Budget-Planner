//
//  HomeView.swift
//  Pocket Ledger
//
//  The Home screen: streak, Total + Available balance, this period's income vs
//  expense, a budget-alert slot (placeholder until Budgets), and recent
//  activity. Values are live via @Query and computed with the pure services.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    /// Switches to the Activity tab (optionally pre-filtered by wallet in Phase C).
    var onShowActivity: (Wallet?) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money
    @State private var showSettings = false

    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil }, sort: \Transaction.occurredAt, order: .reverse)
    private var transactions: [Transaction]
    @Query(filter: #Predicate<Wallet> { $0.deletedAt == nil }, sort: \Wallet.sortOrder)
    private var wallets: [Wallet]
    @Query(filter: #Predicate<Goal> { $0.deletedAt == nil })
    private var goals: [Goal]
    @Query(filter: #Predicate<Budget> { $0.deletedAt == nil && $0.isArchived == false })
    private var budgets: [Budget]
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }
    private var currencyCode: String { settings?.mainCurrency ?? "USD" }
    private var budgetStartDay: Int { settings?.budgetStartDay ?? 1 }

    private var period: BudgetPeriod {
        PeriodCalculator.period(for: .now, startDay: budgetStartDay, timeZoneID: TimeZone.current.identifier)
    }
    private var total: Decimal { BalanceService.totalBalance(wallets: wallets, transactions: transactions) }
    private var reserved: Decimal { BalanceService.reserved(goals: goals.filter { $0.status != .archived }) }
    private var available: Decimal { total - reserved }
    private var periodTotals: (income: Decimal, expense: Decimal) {
        HomeMetrics.periodTotals(transactions: transactions, period: period)
    }
    private var streak: Int { HomeMetrics.loggingStreak(transactions: transactions) }
    private var recent: [Transaction] { Array(transactions.prefix(5)) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    mascotRow
                    balanceCard
                    incomeExpenseRow
                    if let alert = alertBudget { budgetAlertCard(alert.budget, alert.stats) }
                    recentActivityCard
                }
                .padding(.horizontal)
                .padding(.bottom, 96)   // clear the floating + button
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                Text("Home").font(.largeTitle.weight(.bold)).foregroundStyle(Theme.text)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.title2).foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    // MARK: Mascot + streak

    private var mascotRow: some View {
        HStack(spacing: 12) {
            MascotView(size: 60)
            VStack(alignment: .leading, spacing: 2) {
                if streak > 0 {
                    Text("\(streak)-day logging streak")
                        .font(.headline).foregroundStyle(Theme.text)
                } else {
                    Text("Start your logging streak")
                        .font(.headline).foregroundStyle(Theme.text)
                }
                Text("Keep logging to stay on track.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Balance card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOTAL BALANCE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            AmountText(amount: total, style: .neutral, tint: .white)
                .font(.system(size: 40, weight: .bold))
                .contentTransition(.numericText())
                .animation(.snappy, value: total)
            Text("Available \(money.string(available))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(wallets) { wallet in
                        Button { onShowActivity(wallet) } label: {
                            Text("\(wallet.name) \(money.compact(BalanceService.walletBalance(wallet, transactions: transactions)))")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12).frame(height: 32)
                                .overlay(Capsule().stroke(.white.opacity(0.4)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Income / Expense

    private var incomeExpenseRow: some View {
        let totals = periodTotals
        let maxValue = max(totals.income, totals.expense, 1)
        return HStack(spacing: 12) {
            flowCard(titleKey: "INCOME · \(monthLabel)", amount: totals.income, style: .income,
                     fraction: fraction(totals.income, of: maxValue), color: Theme.income)
            flowCard(titleKey: "EXPENSE · \(monthLabel)", amount: totals.expense, style: .expense,
                     fraction: fraction(totals.expense, of: maxValue), color: Theme.expense)
        }
    }

    private func flowCard(titleKey: LocalizedStringKey, amount: Decimal, style: AmountStyle, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            AmountText(amount: amount, style: style)
                .font(.title3.weight(.bold))
            bar(fraction: fraction, color: color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func bar(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border.opacity(0.5))
                Capsule().fill(color).frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
    }

    private func fraction(_ value: Decimal, of maxValue: Decimal) -> Double {
        let v = (value as NSDecimalNumber).doubleValue
        let m = (maxValue as NSDecimalNumber).doubleValue
        return m > 0 ? min(1, v / m) : 0
    }

    private var monthLabel: String {
        period.start.formatted(.dateTime.month(.abbreviated))
    }

    // MARK: Budget alert

    /// The budget most worth surfacing: the highest usage that is at least 80%.
    private var alertBudget: (budget: Budget, stats: BudgetStats)? {
        budgets
            .map { ($0, BudgetService.stats(for: $0, period: period, transactions: transactions)) }
            .filter { $0.1.isOver80 }
            .max { $0.1.fraction < $1.1.fraction }
            .map { (budget: $0.0, stats: $0.1) }
    }

    private func budgetAlertCard(_ budget: Budget, _ stats: BudgetStats) -> some View {
        let daysLeft = BudgetService.daysLeft(period: period, asOf: .now, timeZoneID: TimeZone.current.identifier)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BUDGET ALERT").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(Int((stats.fraction * 100).rounded()))% used")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .foregroundStyle(stats.isOver100 ? Theme.expense : Theme.warning)
                    .overlay(Capsule().stroke(stats.isOver100 ? Theme.expense : Theme.warning))
            }
            HStack {
                if let category = budget.category {
                    CategoryLabel(category: category).font(.headline).foregroundStyle(Theme.text)
                }
                Spacer()
                Text("\(money.string(stats.remaining)) left · \(daysLeft) days")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            ProgressBar(fraction: stats.fraction, color: stats.isOver100 ? Theme.expense : Theme.warning)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Recent activity

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent activity").font(.headline).foregroundStyle(Theme.text)
                Spacer()
                Button("See all") { onShowActivity(nil) }
                    .font(.subheadline).foregroundStyle(Theme.primary)
            }
            if recent.isEmpty {
                VStack(spacing: 6) {
                    Text("No records yet").foregroundStyle(Theme.secondaryText)
                    Text("Tap + to add your first one").font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, tx in
                    TransactionRow(transaction: tx)
                    if index < recent.count - 1 { Divider() }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }
}

#Preview("USD") {
    HomeView()
        .modelContainer(PreviewData.container())
        .environment(\.money, MoneyFormatter(currencyCode: "USD"))
}

#Preview("MMK") {
    HomeView()
        .modelContainer(PreviewData.container())
        .environment(\.money, MoneyFormatter(currencyCode: "MMK"))
}
