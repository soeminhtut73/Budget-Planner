//
//  RecurringService.swift
//  Pocket Ledger
//
//  Monthly recurrence. The schedule math is pure and testable; posting due
//  rules writes transactions on app launch. A day-of-month beyond a month's
//  length is clamped to the last day (the 31st in a 30-day month → the 30th).
//

import Foundation
import SwiftData

enum RecurringSchedule {
    /// The next monthly fire date after `date`, on `dayOfMonth` (clamped to the
    /// next month's length), keeping `date`'s time of day.
    static func nextMonthlyDate(after date: Date, dayOfMonth: Int, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .hour, .minute, .second], from: date)
        guard
            let firstOfThisMonth = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)),
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfThisMonth)
        else { return date }

        let nextComps = calendar.dateComponents([.year, .month], from: nextMonth)
        let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 28
        let day = min(max(dayOfMonth, 1), daysInNextMonth)

        var result = DateComponents()
        result.year = nextComps.year
        result.month = nextComps.month
        result.day = day
        result.hour = comps.hour
        result.minute = comps.minute
        result.second = comps.second
        return calendar.date(from: result) ?? date
    }
}

enum RecurringService {
    /// Posts every rule occurrence due at or before `asOf`, advancing each
    /// rule's `nextOccurrence`. Returns the transactions created.
    @MainActor
    @discardableResult
    static func postDueRules(context: ModelContext, asOf: Date = .now) throws -> [Transaction] {
        let repo = SwiftDataRecurringRuleRepository(context: context)
        let rules = try repo.activeRules()
        var created: [Transaction] = []
        let timeZoneID = TimeZone.current.identifier

        for rule in rules {
            var fire = rule.nextOccurrence
            var safety = 0
            while fire <= asOf, safety < 600 {
                let tx = Transaction(
                    kind: rule.kind,
                    amount: rule.amount,
                    occurredAt: fire,
                    timeZoneID: timeZoneID,
                    note: rule.note,
                    wallet: rule.wallet,
                    category: rule.category,
                    recurringRule: rule
                )
                context.insert(tx)
                created.append(tx)
                fire = RecurringSchedule.nextMonthlyDate(after: fire, dayOfMonth: rule.dayOfMonth)
                safety += 1
            }
            if rule.nextOccurrence != fire {
                rule.nextOccurrence = fire
                rule.updatedAt = .now
            }
        }

        if !created.isEmpty {
            try context.save()
        }
        return created
    }
}
