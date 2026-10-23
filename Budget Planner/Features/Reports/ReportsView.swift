//
//  ReportsView.swift
//  Pocket Ledger
//
//  Reports: Week / Month / Year switcher, a cash-flow bar chart (income vs
//  expense over 6 periods) and spending by category (donut + list) for the
//  current period. Built with Swift Charts.
//

import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money

    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query(filter: #Predicate<Category> { $0.deletedAt == nil })
    private var categories: [Category]
    @Query private var settingsList: [AppSettings]

    @State private var granularity: ReportGranularity = .month
    @State private var showExport = false

    private let palette: [Color] = [Theme.primary, Theme.expense, Theme.warning, .blue, .purple, .pink, .teal, .indigo]
    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }
    private var tzID: String { TimeZone.current.identifier }

    private var points: [CashFlowPoint] {
        ReportsService.cashFlow(transactions: transactions, granularity: granularity, count: 6, timeZoneID: tzID)
    }
    private var currentPeriod: (start: Date, end: Date)? {
        ReportsService.periods(granularity: granularity, count: 1, timeZoneID: tzID).last
    }
    private var breakdown: [CategorySpend] {
        guard let period = currentPeriod else { return [] }
        return ReportsService.categoryBreakdown(transactions: transactions, start: period.start, end: period.end)
    }
    private var breakdownTotal: Decimal { breakdown.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SegmentedToggle(selection: $granularity, options: [
                        (.week, "Week"), (.month, "Month"), (.year, "Year"),
                    ])
                    cashFlowCard
                    categoryCard
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showExport = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Export")
                }
            }
            .sheet(isPresented: $showExport) { ExportView() }
        }
    }

    // MARK: Cash flow

    private var cashFlowCard: some View {
        let incomeLabel = String(localized: "Income")
        let expenseLabel = String(localized: "Expense")
        let labels = points.map { label(for: $0.start) }
        return VStack(alignment: .leading, spacing: 10) {
            Text("CASH FLOW").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            if points.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
                emptyChart
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Period", label(for: point.start)),
                            y: .value("Amount", (point.income as NSDecimalNumber).doubleValue)
                        )
                        .foregroundStyle(by: .value("Type", incomeLabel))
                        .position(by: .value("Type", incomeLabel))

                        BarMark(
                            x: .value("Period", label(for: point.start)),
                            y: .value("Amount", (point.expense as NSDecimalNumber).doubleValue)
                        )
                        .foregroundStyle(by: .value("Type", expenseLabel))
                        .position(by: .value("Type", expenseLabel))
                    }
                }
                .chartForegroundStyleScale([incomeLabel: Theme.income, expenseLabel: Theme.expense])
                .chartXScale(domain: labels)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(money.compact(Decimal(amount)))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Category

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPENDING BY CATEGORY").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            if breakdown.isEmpty {
                emptyChart
            } else {
                Chart(Array(breakdown.enumerated()), id: \.element.id) { index, spend in
                    SectorMark(
                        angle: .value("Amount", (spend.amount as NSDecimalNumber).doubleValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(palette[index % palette.count])
                }
                .frame(height: 200)

                VStack(spacing: 8) {
                    ForEach(Array(breakdown.enumerated()), id: \.element.id) { index, spend in
                        categoryRow(index: index, spend: spend)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func categoryRow(index: Int, spend: CategorySpend) -> some View {
        let name = categories.first { $0.id == spend.categoryID }?.displayName ?? "—"
        let pct = breakdownTotal > 0 ? ((spend.amount / breakdownTotal) as NSDecimalNumber).doubleValue * 100 : 0
        return HStack(spacing: 10) {
            Circle().fill(palette[index % palette.count]).frame(width: 10, height: 10)
            Text(name).foregroundStyle(Theme.text)
            Spacer()
            Text("\(Int(pct.rounded()))%").font(.caption).foregroundStyle(Theme.secondaryText)
            Text(money.string(spend.amount))
                .fontWeight(.semibold).foregroundStyle(Theme.text)
        }
        .font(.subheadline)
    }

    private var emptyChart: some View {
        Text("No data for this period")
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity).frame(height: 120)
    }

    private func label(for start: Date) -> String {
        switch granularity {
        case .week: return start.formatted(.dateTime.day().month(.abbreviated))
        case .month: return start.formatted(.dateTime.month(.abbreviated))
        case .year: return start.formatted(.dateTime.year())
        }
    }
}

#Preview {
    ReportsView().modelContainer(PreviewData.container())
}
