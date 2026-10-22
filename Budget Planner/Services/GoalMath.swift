//
//  GoalMath.swift
//  Pocket Ledger
//
//  Pure goal arithmetic shared by BalanceService (for reserved/Available) now
//  and GoalService later. Saved = deposits − withdrawals − amounts spent.
//

import Foundation

enum GoalMath {
    /// Saved amount from a set of entries (ignores soft-deleted ones).
    static func saved(entries: [GoalEntry]) -> Decimal {
        entries.reduce(Decimal(0)) { running, entry in
            guard entry.deletedAt == nil else { return running }
            switch entry.kind {
            case .deposit:  return running + entry.amount
            case .withdraw: return running - entry.amount
            case .spend:    return running - entry.amount
            }
        }
    }

    /// Saved amount for a goal.
    static func saved(for goal: Goal) -> Decimal {
        saved(entries: goal.entries ?? [])
    }

    /// Progress toward the target (0…, can exceed 1). 0 when target is 0.
    static func progress(saved: Decimal, target: Decimal) -> Double {
        guard target > 0 else { return 0 }
        return (saved as NSDecimalNumber).doubleValue / (target as NSDecimalNumber).doubleValue
    }

    static func isComplete(saved: Decimal, target: Decimal) -> Bool {
        target > 0 && saved >= target
    }

    /// Whole months from `from` to `targetDate`, minimum 1 (compared by month).
    static func monthsRemaining(to targetDate: Date, from: Date = .now, timeZoneID: String = TimeZone.current.identifier) -> Int {
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        let a = calendar.date(from: calendar.dateComponents([.year, .month], from: from)) ?? from
        let b = calendar.date(from: calendar.dateComponents([.year, .month], from: targetDate)) ?? targetDate
        let months = calendar.dateComponents([.month], from: a, to: b).month ?? 0
        return max(1, months)
    }

    /// Amount to set aside each month to reach the target by its date. Nil when
    /// there is no target date (don't show it). 0 once the goal is reached.
    static func monthlyNeeded(saved: Decimal, target: Decimal, targetDate: Date?, from: Date = .now, timeZoneID: String = TimeZone.current.identifier) -> Decimal? {
        guard let targetDate else { return nil }
        let remaining = max(0, target - saved)
        return remaining / Decimal(monthsRemaining(to: targetDate, from: from, timeZoneID: timeZoneID))
    }

    /// Deposits (only) made within the given period.
    static func depositsInPeriod(entries: [GoalEntry], period: BudgetPeriod) -> Decimal {
        entries.reduce(Decimal(0)) { running, entry in
            guard entry.deletedAt == nil, entry.kind == .deposit, period.contains(entry.occurredAt) else { return running }
            return running + entry.amount
        }
    }

    /// "On track" if this period's deposits meet the monthly need.
    static func isOnTrack(depositsThisPeriod: Decimal, monthlyNeeded: Decimal) -> Bool {
        depositsThisPeriod >= monthlyNeeded
    }
}
