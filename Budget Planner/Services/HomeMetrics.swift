//
//  HomeMetrics.swift
//  Pocket Ledger
//
//  Pure metrics for the Home screen: the logging streak and the current
//  period's income/expense totals. Each record is bucketed by its own local
//  day (occurredAt + timeZoneID), never by UTC.
//

import Foundation

enum HomeMetrics {
    /// Consecutive local days, counting back from `asOf`, that have at least one
    /// non-deleted record. If nothing is logged on the `asOf` day, the streak is 0.
    static func loggingStreak(
        transactions: [Transaction],
        asOf: Date = .now,
        timeZoneID: String = TimeZone.current.identifier
    ) -> Int {
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)

        let loggedDays = Set(
            transactions
                .filter { $0.deletedAt == nil }
                .map { dayKey(of: $0.occurredAt, timeZoneID: $0.timeZoneID) }
        )

        var streak = 0
        var cursor = asOf
        while loggedDays.contains(dayKey(of: cursor, timeZoneID: timeZoneID)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Income and expense totals for the records whose instant falls in `period`.
    static func periodTotals(
        transactions: [Transaction],
        period: BudgetPeriod
    ) -> (income: Decimal, expense: Decimal) {
        var income: Decimal = 0
        var expense: Decimal = 0
        for tx in transactions where tx.deletedAt == nil && period.contains(tx.occurredAt) {
            switch tx.kind {
            case .income: income += tx.amount
            case .expense: expense += tx.amount
            }
        }
        return (income, expense)
    }

    /// A comparable integer key for a date's local calendar day.
    private static func dayKey(of date: Date, timeZoneID: String) -> Int {
        let c = PeriodCalculator.localComponents(of: date, timeZoneID: timeZoneID)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
