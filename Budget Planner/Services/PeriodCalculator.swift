//
//  PeriodCalculator.swift
//  Pocket Ledger
//
//  Which day/month a record belongs to is always decided in its local time
//  zone (`occurredAt` in UTC + `timeZoneID`), never in UTC. Budget periods
//  are calendar months by default; a start day of 1...28 shifts the boundary.
//

import Foundation

/// A half-open budget period: `[start, end)` — `start` inclusive, `end` exclusive.
struct BudgetPeriod: Equatable, Sendable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

enum PeriodCalculator {
    /// A Gregorian calendar fixed to the given time zone (falls back to the
    /// current zone if the identifier is unknown).
    static func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    /// Clamps the configured start day to the supported range (1...28), so
    /// every month has that day.
    static func normalizedStartDay(_ day: Int) -> Int {
        min(max(day, 1), 28)
    }

    /// Local calendar components (year/month/day/hour/minute) of a UTC instant,
    /// as seen in `timeZoneID`.
    static func localComponents(of date: Date, timeZoneID: String) -> DateComponents {
        calendar(timeZoneID: timeZoneID)
            .dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    /// The budget period that contains `date`, for the given start day and zone.
    static func period(for date: Date, startDay: Int, timeZoneID: String) -> BudgetPeriod {
        let calendar = calendar(timeZoneID: timeZoneID)
        let start = normalizedStartDay(startDay)
        let comps = calendar.dateComponents([.year, .month, .day], from: date)

        // Start of the start-day in this local month (00:00 local).
        var anchorComps = DateComponents()
        anchorComps.year = comps.year
        anchorComps.month = comps.month
        anchorComps.day = start
        guard let anchorThisMonth = calendar.date(from: anchorComps) else {
            // Should not happen for day <= 28; degrade gracefully.
            return BudgetPeriod(start: date, end: date)
        }

        let currentDay = comps.day ?? start
        let periodStart: Date
        if currentDay >= start {
            periodStart = anchorThisMonth
        } else {
            periodStart = calendar.date(byAdding: .month, value: -1, to: anchorThisMonth) ?? anchorThisMonth
        }
        let periodEnd = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
        return BudgetPeriod(start: periodStart, end: periodEnd)
    }
}
