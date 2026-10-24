//
//  BudgetService.swift
//  Pocket Ledger
//
//  Pure budget math. A budget is a spending limit, never money: "spent" is
//  always calculated from transactions in the period's date range, counting
//  only expenses in the category and EXCLUDING expenses paid from a goal
//  (planned spending shouldn't break a monthly budget). Limits keep a history;
//  a period uses the limit that was effective at its start.
//

import Foundation

/// Computed state of a budget for a period.
struct BudgetStats {
    let spent: Decimal
    let limit: Decimal
    let remaining: Decimal
    let fraction: Double
    let isOver80: Bool
    let isOver100: Bool
}

enum BudgetService {
    /// Computed state of a budget for a period.
    static func stats(for budget: Budget, period: BudgetPeriod, transactions: [Transaction]) -> BudgetStats {
        let categoryID = budget.category?.id ?? UUID()
        let spent = spent(categoryID: categoryID, period: period, transactions: transactions)
        let limit = limit(from: budget.limits ?? [], periodStart: period.start) ?? 0
        return BudgetStats(
            spent: spent,
            limit: limit,
            remaining: remaining(limit: limit, spent: spent),
            fraction: fraction(spent: spent, limit: limit),
            isOver80: isAtOrOver(0.8, spent: spent, limit: limit),
            isOver100: isAtOrOver(1.0, spent: spent, limit: limit)
        )
    }

    /// Whether any active budget is at or over 100% of its limit this period.
    /// Drives the mascot's `overLimit` (sad) base mood. Goal-paid expenses are
    /// excluded from the spent total, just like in `stats`.
    static func anyBudgetOverLimit(budgets: [Budget], period: BudgetPeriod, transactions: [Transaction]) -> Bool {
        budgets.contains { budget in
            stats(for: budget, period: period, transactions: transactions).isOver100
        }
    }

    /// Expenses for a category within a period, excluding goal-paid expenses.
    static func spent(categoryID: UUID, period: BudgetPeriod, transactions: [Transaction]) -> Decimal {
        transactions.reduce(Decimal(0)) { running, tx in
            guard tx.deletedAt == nil,
                  tx.kind == .expense,
                  tx.paidFromGoal == nil,
                  tx.category?.id == categoryID,
                  period.contains(tx.occurredAt)
            else { return running }
            return running + tx.amount
        }
    }

    /// The limit effective at `periodStart` — the one with the greatest
    /// `effectiveFrom` not after it. Nil if the budget had no limit yet.
    static func limit(from limits: [BudgetLimit], periodStart: Date) -> Decimal? {
        limits
            .filter { $0.deletedAt == nil && $0.effectiveFrom <= periodStart }
            .max { $0.effectiveFrom < $1.effectiveFrom }?
            .amount
    }

    static func remaining(limit: Decimal, spent: Decimal) -> Decimal {
        limit - spent
    }

    /// Fraction spent of the limit (0…, can exceed 1). 0 when the limit is 0.
    static func fraction(spent: Decimal, limit: Decimal) -> Double {
        guard limit > 0 else { return 0 }
        return (spent as NSDecimalNumber).doubleValue / (limit as NSDecimalNumber).doubleValue
    }

    static func isAtOrOver(_ threshold: Double, spent: Decimal, limit: Decimal) -> Bool {
        limit > 0 && fraction(spent: spent, limit: limit) >= threshold
    }

    /// Total period expenses in categories that have no active budget
    /// (goal-paid expenses excluded, to match budget accounting).
    static func spentOutsideBudgets(
        period: BudgetPeriod,
        transactions: [Transaction],
        budgetedCategoryIDs: Set<UUID>
    ) -> Decimal {
        transactions.reduce(Decimal(0)) { running, tx in
            guard tx.deletedAt == nil,
                  tx.kind == .expense,
                  tx.paidFromGoal == nil,
                  period.contains(tx.occurredAt)
            else { return running }
            if let id = tx.category?.id, budgetedCategoryIDs.contains(id) { return running }
            return running + tx.amount
        }
    }

    // MARK: Pace

    /// Days remaining in the period, counting the `asOf` day (minimum 1).
    static func daysLeft(period: BudgetPeriod, asOf: Date, timeZoneID: String) -> Int {
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        let startOfToday = calendar.startOfDay(for: asOf)
        let startOfEnd = calendar.startOfDay(for: period.end)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfEnd).day ?? 1
        return max(1, days)
    }

    /// Total days in the period.
    static func totalDays(period: BudgetPeriod, timeZoneID: String) -> Int {
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        let days = calendar.dateComponents([.day], from: period.start, to: period.end).day ?? 30
        return max(1, days)
    }

    /// How much per day keeps the budget from going over: remaining ÷ days left.
    static func perDayAllowance(remaining: Decimal, period: BudgetPeriod, asOf: Date, timeZoneID: String) -> Decimal {
        let left = daysLeft(period: period, asOf: asOf, timeZoneID: timeZoneID)
        return remaining / Decimal(left)
    }

    /// Projected spend at the current pace by the period's end.
    static func paceProjection(spent: Decimal, period: BudgetPeriod, asOf: Date, timeZoneID: String) -> Decimal {
        let total = totalDays(period: period, timeZoneID: timeZoneID)
        let left = daysLeft(period: period, asOf: asOf, timeZoneID: timeZoneID)
        let elapsed = max(1, total - left + 1)
        return spent / Decimal(elapsed) * Decimal(total)
    }

    /// True if adding this expense pushed `spent` from below the threshold to at
    /// or above it (so an alert should fire once, on the crossing).
    static func crossedThreshold(_ threshold: Double, priorSpent: Decimal, newSpent: Decimal, limit: Decimal) -> Bool {
        guard limit > 0 else { return false }
        let was = fraction(spent: priorSpent, limit: limit)
        let now = fraction(spent: newSpent, limit: limit)
        return was < threshold && now >= threshold
    }
}
