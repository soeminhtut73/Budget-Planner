//
//  BudgetServiceTests.swift
//  Budget PlannerTests
//
//  Pure budget math: spent (excluding goal-paid), limit history, outside
//  budgets, and threshold crossing.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Budget math")
struct BudgetServiceTests {

    private var octoberPeriod: BudgetPeriod {
        PeriodCalculator.period(for: utcDate(year: 2026, month: 10, day: 15), startDay: 1, timeZoneID: "UTC")
    }

    private func expense(_ amount: Decimal, in category: Budget_Planner.Category, day: Int, goal: Goal? = nil) -> Transaction {
        Transaction(kind: .expense, amount: amount,
                    occurredAt: utcDate(year: 2026, month: 10, day: day, hour: 9),
                    timeZoneID: "UTC", category: category, paidFromGoal: goal)
    }

    @Test("Food 342 of 400: spent, remaining and 80% crossing")
    func foodWorkedExample() {
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let txs = [expense(300, in: food, day: 3), expense(42, in: food, day: 10)]
        let spent = BudgetService.spent(categoryID: food.id, period: octoberPeriod, transactions: txs)
        #expect(spent == dec("342"))
        #expect(BudgetService.remaining(limit: 400, spent: spent) == dec("58"))
        #expect(BudgetService.isAtOrOver(0.8, spent: spent, limit: 400))
        #expect(!BudgetService.isAtOrOver(1.0, spent: spent, limit: 400))
    }

    @Test("Expense paid from a goal is excluded from budget spent")
    func goalPaidExcluded() {
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let goal = Goal(name: "Trip")
        let txs = [
            expense(50, in: food, day: 2),
            expense(100, in: food, day: 5, goal: goal),   // goal-paid → excluded
        ]
        #expect(BudgetService.spent(categoryID: food.id, period: octoberPeriod, transactions: txs) == dec("50"))
    }

    @Test("Limit history: a past period uses the limit active then")
    func limitHistory() {
        let oct = BudgetLimit(amount: 400, effectiveFrom: utcDate(year: 2026, month: 10, day: 1))
        let dec = BudgetLimit(amount: 500, effectiveFrom: utcDate(year: 2026, month: 12, day: 1))
        let limits = [oct, dec]
        let octStart = utcDate(year: 2026, month: 10, day: 1)
        let novStart = utcDate(year: 2026, month: 11, day: 1)
        let decStart = utcDate(year: 2026, month: 12, day: 1)
        #expect(BudgetService.limit(from: limits, periodStart: octStart) == 400)
        #expect(BudgetService.limit(from: limits, periodStart: novStart) == 400)  // Dec not yet effective
        #expect(BudgetService.limit(from: limits, periodStart: decStart) == 500)
    }

    @Test("Spent outside budgets sums only non-budgeted categories")
    func outsideBudgets() {
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let fun = Budget_Planner.Category(kind: .expense, defaultKey: "fun")
        let txs = [expense(50, in: food, day: 2), expense(20, in: fun, day: 3)]
        let outside = BudgetService.spentOutsideBudgets(
            period: octoberPeriod, transactions: txs, budgetedCategoryIDs: [food.id]
        )
        #expect(outside == dec("20"))   // only fun is outside
    }

    @Test("Threshold crossing fires once, on the crossing")
    func crossing() {
        // Prior 70% → new 85% crosses 0.8.
        #expect(BudgetService.crossedThreshold(0.8, priorSpent: 280, newSpent: 340, limit: 400))
        // Already past 80% → no re-cross.
        #expect(!BudgetService.crossedThreshold(0.8, priorSpent: 340, newSpent: 360, limit: 400))
        // Crossing 100%.
        #expect(BudgetService.crossedThreshold(1.0, priorSpent: 390, newSpent: 410, limit: 400))
    }
}
