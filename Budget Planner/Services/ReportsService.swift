//
//  ReportsService.swift
//  Pocket Ledger
//
//  Pure aggregation for Reports: cash flow (income vs expense) over the last N
//  calendar periods, and spending by category for a period. Reports include
//  expenses paid from a goal (they are real money out), unlike budgets.
//

import Foundation

enum ReportGranularity: Hashable {
    case week, month, year
}

struct CashFlowPoint: Identifiable {
    var id: Date { start }
    let start: Date
    let income: Decimal
    let expense: Decimal
}

struct CategorySpend: Identifiable {
    var id: UUID { categoryID }
    let categoryID: UUID
    let amount: Decimal
}

enum ReportsService {
    /// The last `count` periods (oldest → newest) for the granularity, as
    /// half-open `[start, end)` ranges in the given time zone.
    static func periods(
        granularity: ReportGranularity,
        count: Int = 6,
        asOf: Date = .now,
        timeZoneID: String = TimeZone.current.identifier
    ) -> [(start: Date, end: Date)] {
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        let currentStart = periodStart(granularity, of: asOf, calendar: calendar)
        var result: [(Date, Date)] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            let start = add(granularity, to: currentStart, times: -i, calendar: calendar)
            let end = add(granularity, to: start, times: 1, calendar: calendar)
            result.append((start, end))
        }
        return result
    }

    /// Income/expense totals for each of the last `count` periods.
    static func cashFlow(
        transactions: [Transaction],
        granularity: ReportGranularity,
        count: Int = 6,
        asOf: Date = .now,
        timeZoneID: String = TimeZone.current.identifier
    ) -> [CashFlowPoint] {
        periods(granularity: granularity, count: count, asOf: asOf, timeZoneID: timeZoneID).map { range in
            var income: Decimal = 0
            var expense: Decimal = 0
            for tx in transactions where tx.deletedAt == nil && tx.occurredAt >= range.start && tx.occurredAt < range.end {
                switch tx.kind {
                case .income: income += tx.amount
                case .expense: expense += tx.amount
                }
            }
            return CashFlowPoint(start: range.start, income: income, expense: expense)
        }
    }

    /// Expense totals by category for `[start, end)`, largest first. Includes
    /// goal-paid expenses.
    static func categoryBreakdown(
        transactions: [Transaction],
        start: Date,
        end: Date
    ) -> [CategorySpend] {
        var totals: [UUID: Decimal] = [:]
        for tx in transactions where tx.deletedAt == nil && tx.kind == .expense && tx.occurredAt >= start && tx.occurredAt < end {
            guard let id = tx.category?.id else { continue }
            totals[id, default: 0] += tx.amount
        }
        return totals
            .map { CategorySpend(categoryID: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: Private

    private static func periodStart(_ granularity: ReportGranularity, of date: Date, calendar: Calendar) -> Date {
        switch granularity {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
        }
    }

    private static func add(_ granularity: ReportGranularity, to date: Date, times: Int, calendar: Calendar) -> Date {
        let component: Calendar.Component
        switch granularity {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.date(byAdding: component, value: times, to: date) ?? date
    }
}
