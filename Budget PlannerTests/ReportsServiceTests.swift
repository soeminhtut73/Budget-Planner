//
//  ReportsServiceTests.swift
//  Budget PlannerTests
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Reports")
struct ReportsServiceTests {
    private let tz = "UTC"
    private var asOf: Date { utcDate(year: 2026, month: 10, day: 15, hour: 12) }

    private func tx(_ amount: Decimal, kind: TransactionKind, month: Int, day: Int,
                    category: Budget_Planner.Category? = nil, goal: Goal? = nil) -> Transaction {
        Transaction(kind: kind, amount: amount,
                    occurredAt: utcDate(year: 2026, month: month, day: day, hour: 9),
                    timeZoneID: tz, category: category, paidFromGoal: goal)
    }

    @Test("Six monthly periods, oldest first, ending with the current month")
    func monthlyPeriods() {
        let periods = ReportsService.periods(granularity: .month, count: 6, asOf: asOf, timeZoneID: tz)
        #expect(periods.count == 6)
        let cal = PeriodCalculator.calendar(timeZoneID: tz)
        #expect(cal.component(.month, from: periods.first!.start) == 5)   // May
        #expect(cal.component(.month, from: periods.last!.start) == 10)   // October
    }

    @Test("Cash flow sums income and expense per month")
    func cashFlowByMonth() {
        let txs = [
            tx(1000, kind: .income, month: 10, day: 5),
            tx(200, kind: .expense, month: 10, day: 10),
            tx(50, kind: .expense, month: 9, day: 20),
        ]
        let points = ReportsService.cashFlow(transactions: txs, granularity: .month, count: 6, asOf: asOf, timeZoneID: tz)
        let cal = PeriodCalculator.calendar(timeZoneID: tz)
        let oct = points.first { cal.component(.month, from: $0.start) == 10 }
        let sep = points.first { cal.component(.month, from: $0.start) == 9 }
        #expect(oct?.income == dec("1000"))
        #expect(oct?.expense == dec("200"))
        #expect(sep?.expense == dec("50"))
    }

    @Test("Category breakdown is largest-first and includes goal-paid expenses")
    func categoryBreakdown() {
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let transport = Budget_Planner.Category(kind: .expense, defaultKey: "transport")
        let goal = Goal(name: "Trip")
        let txs = [
            tx(242, kind: .expense, month: 10, day: 3, category: food),
            tx(100, kind: .expense, month: 10, day: 8, category: food, goal: goal), // goal-paid, still counts
            tx(20, kind: .expense, month: 10, day: 9, category: transport),
        ]
        let start = utcDate(year: 2026, month: 10, day: 1)
        let end = utcDate(year: 2026, month: 11, day: 1)
        let breakdown = ReportsService.categoryBreakdown(transactions: txs, start: start, end: end)
        #expect(breakdown.count == 2)
        #expect(breakdown.first?.categoryID == food.id)
        #expect(breakdown.first?.amount == dec("342"))
        #expect(breakdown.last?.amount == dec("20"))
    }
}
