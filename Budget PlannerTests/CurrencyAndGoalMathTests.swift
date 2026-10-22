//
//  CurrencyAndGoalMathTests.swift
//  Budget PlannerTests
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Currency rounding")
struct CurrencyRoundingTests {

    @Test("Minor units per currency")
    func minorUnits() {
        #expect(CurrencyRounding.minorUnits(for: "USD") == 2)
        #expect(CurrencyRounding.minorUnits(for: "SGD") == 2)
        #expect(CurrencyRounding.minorUnits(for: "MMK") == 0)
        #expect(CurrencyRounding.minorUnits(for: "VND") == 0)
        #expect(CurrencyRounding.minorUnits(for: "usd") == 2)  // case-insensitive
    }

    @Test("Rounds to the currency's minor units, half up")
    func roundsHalfUp() {
        #expect(CurrencyRounding.rounded(dec("12.345"), currencyCode: "USD") == dec("12.35"))
        #expect(CurrencyRounding.rounded(dec("12.344"), currencyCode: "USD") == dec("12.34"))
        #expect(CurrencyRounding.rounded(dec("1234.5"), currencyCode: "MMK") == dec("1235"))
        #expect(CurrencyRounding.rounded(dec("1234.4"), currencyCode: "MMK") == dec("1234"))
    }

    @Test("Decimal arithmetic stays exact (no floating-point drift)")
    func decimalIsExact() {
        #expect(dec("0.1") + dec("0.2") == dec("0.3"))
        let sum = (0..<10).reduce(Decimal(0)) { acc, _ in acc + dec("0.1") }
        #expect(sum == dec("1.0"))
    }
}

@Suite("Goal math")
struct GoalMathTests {

    @Test("Saved = deposits − withdrawals − spends")
    func savedArithmetic() {
        let goal = Goal(name: "Trip")
        goal.entries = [
            GoalEntry(kind: .deposit, amount: dec("2100"), goal: goal),
            GoalEntry(kind: .deposit, amount: dec("100"), goal: goal),
            GoalEntry(kind: .spend, amount: dec("100"), goal: goal),
            GoalEntry(kind: .withdraw, amount: dec("50"), goal: goal),
        ]
        #expect(GoalMath.saved(for: goal) == dec("2050"))
    }

    @Test("Soft-deleted goal entries are ignored")
    func ignoresSoftDeleted() {
        let goal = Goal(name: "Trip")
        let removed = GoalEntry(kind: .deposit, amount: dec("500"), goal: goal)
        removed.deletedAt = .now
        goal.entries = [
            GoalEntry(kind: .deposit, amount: dec("200"), goal: goal),
            removed,
        ]
        #expect(GoalMath.saved(for: goal) == dec("200"))
    }

    @Test("A goal with no entries is saved 0")
    func emptyGoal() {
        #expect(GoalMath.saved(for: Goal(name: "Empty")) == dec("0"))
    }

    @Test("Progress and completion")
    func progressAndCompletion() {
        #expect(GoalMath.progress(saved: dec("50"), target: dec("200")) == 0.25)
        #expect(!GoalMath.isComplete(saved: dec("499"), target: dec("500")))
        #expect(GoalMath.isComplete(saved: dec("500"), target: dec("500")))
    }

    @Test("Monthly needed divides the remainder over the months left")
    func monthlyNeeded() {
        let from = utcDate(year: 2026, month: 10, day: 1)
        let targetDate = utcDate(year: 2027, month: 2, day: 1)   // 4 months out
        let needed = GoalMath.monthlyNeeded(saved: dec("100"), target: dec("500"),
                                            targetDate: targetDate, from: from, timeZoneID: "UTC")
        #expect(needed == dec("100"))
        // No target date → nil (don't show).
        #expect(GoalMath.monthlyNeeded(saved: 0, target: 500, targetDate: nil) == nil)
    }

    @Test("On track when this period's deposits meet the monthly need")
    func onTrack() {
        let period = PeriodCalculator.period(for: utcDate(year: 2026, month: 10, day: 15), startDay: 1, timeZoneID: "UTC")
        let goal = Goal(name: "Trip")
        goal.entries = [
            GoalEntry(kind: .deposit, amount: dec("120"), occurredAt: utcDate(year: 2026, month: 10, day: 5), timeZoneID: "UTC", goal: goal),
        ]
        let deposits = GoalMath.depositsInPeriod(entries: goal.entries ?? [], period: period)
        #expect(deposits == dec("120"))
        #expect(GoalMath.isOnTrack(depositsThisPeriod: deposits, monthlyNeeded: dec("100")))
        #expect(!GoalMath.isOnTrack(depositsThisPeriod: deposits, monthlyNeeded: dec("150")))
    }
}
