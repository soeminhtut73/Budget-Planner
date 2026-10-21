//
//  PhaseBTests.swift
//  Budget PlannerTests
//
//  Pure tests for the amount keypad model and the monthly recurrence schedule.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Amount input")
struct AmountInputTests {

    @Test("Typing 1 2 . 5 0 gives 12.50 for a 2-minor currency")
    func typesDecimal() {
        var input = AmountInput(minorUnits: 2)
        input.tapDigit(1); input.tapDigit(2); input.tapDot(); input.tapDigit(5); input.tapDigit(0)
        #expect(input.value == dec("12.5"))
    }

    @Test("Typing whole digits gives a whole amount")
    func typesWhole() {
        var input = AmountInput(minorUnits: 2)
        for d in [3, 0, 0, 0] { input.tapDigit(d) }
        #expect(input.value == dec("3000"))
    }

    @Test("A leading zero is replaced by the next digit")
    func leadingZero() {
        var input = AmountInput(minorUnits: 2)
        input.tapDigit(0); input.tapDigit(5)
        #expect(input.value == dec("5"))
    }

    @Test("Fraction length is capped at the minor units")
    func fractionCap() {
        var input = AmountInput(minorUnits: 2)
        input.tapDigit(1); input.tapDot(); input.tapDigit(5); input.tapDigit(5); input.tapDigit(5)
        #expect(input.value == dec("1.55"))
    }

    @Test("A 0-minor currency ignores the dot")
    func zeroMinorIgnoresDot() {
        var input = AmountInput(minorUnits: 0)
        input.tapDigit(1); input.tapDigit(2); input.tapDot(); input.tapDigit(0); input.tapDigit(0)
        #expect(input.value == dec("1200"))
    }

    @Test("Delete walks back through fraction, dot, then integer")
    func deleteSequence() {
        var input = AmountInput(minorUnits: 2)
        input.tapDigit(1); input.tapDigit(2); input.tapDot(); input.tapDigit(5)
        input.tapDelete()                 // removes 5
        #expect(input.value == dec("12"))
        input.tapDelete()                 // leaves fraction mode
        input.tapDelete()                 // removes 2
        #expect(input.value == dec("1"))
    }

    @Test("Seeding from an existing amount round-trips")
    func fromExisting() {
        let a = AmountInput.from(dec("12.50"), minorUnits: 2)
        #expect(a.value == dec("12.5"))
        let b = AmountInput.from(dec("3000"), minorUnits: 2)
        #expect(b.value == dec("3000"))
        let c = AmountInput.from(dec("1500"), minorUnits: 0)
        #expect(c.value == dec("1500"))
    }
}

@Suite("Recurring schedule")
struct RecurringScheduleTests {
    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }

    @Test("Day 31 in a 30-day month posts on the last day")
    func clampsToLastDay() {
        let cal = utcCalendar
        // Mar 31 09:00 → Apr 30 09:00 (April has 30 days)
        let mar31 = utcDate(year: 2025, month: 3, day: 31, hour: 9)
        let next = RecurringSchedule.nextMonthlyDate(after: mar31, dayOfMonth: 31, calendar: cal)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: next)
        #expect(comps.month == 4 && comps.day == 30 && comps.hour == 9)
    }

    @Test("Day 31 from January lands on the last day of February")
    func januaryToFebruary() {
        let cal = utcCalendar
        let jan31 = utcDate(year: 2025, month: 1, day: 31, hour: 8)
        let next = RecurringSchedule.nextMonthlyDate(after: jan31, dayOfMonth: 31, calendar: cal)
        let comps = cal.dateComponents([.month, .day], from: next)
        #expect(comps.month == 2 && comps.day == 28)   // 2025 is not a leap year
    }

    @Test("A mid-month day advances by exactly one month")
    func midMonthAdvance() {
        let cal = utcCalendar
        let jan15 = utcDate(year: 2025, month: 1, day: 15, hour: 10)
        let next = RecurringSchedule.nextMonthlyDate(after: jan15, dayOfMonth: 15, calendar: cal)
        let comps = cal.dateComponents([.month, .day, .hour], from: next)
        #expect(comps.month == 2 && comps.day == 15 && comps.hour == 10)
    }
}

@Suite("Home metrics")
struct HomeMetricsTests {

    private func tx(_ day: Int, kind: TransactionKind = .expense, amount: Decimal = 10) -> Transaction {
        Transaction(kind: kind, amount: amount,
                    occurredAt: utcDate(year: 2026, month: 10, day: day, hour: 9),
                    timeZoneID: "UTC")
    }

    @Test("Streak counts consecutive days back from today")
    func streakConsecutive() {
        let asOf = utcDate(year: 2026, month: 10, day: 22, hour: 12)
        // 22nd, 21st present; gap on 20th; 19th present.
        let txs = [tx(22), tx(21), tx(19)]
        #expect(HomeMetrics.loggingStreak(transactions: txs, asOf: asOf, timeZoneID: "UTC") == 2)
    }

    @Test("Streak is zero when nothing is logged today")
    func streakZeroToday() {
        let asOf = utcDate(year: 2026, month: 10, day: 22, hour: 12)
        let txs = [tx(21), tx(20)]
        #expect(HomeMetrics.loggingStreak(transactions: txs, asOf: asOf, timeZoneID: "UTC") == 0)
    }

    @Test("Period totals sum income and expense inside the period only")
    func periodTotals() {
        let asOf = utcDate(year: 2026, month: 10, day: 22, hour: 12)
        let period = PeriodCalculator.period(for: asOf, startDay: 1, timeZoneID: "UTC")
        let txs = [
            tx(5, kind: .income, amount: dec("1000")),
            tx(10, kind: .expense, amount: dec("200")),
            Transaction(kind: .income, amount: dec("50"),
                        occurredAt: utcDate(year: 2026, month: 9, day: 15, hour: 9), timeZoneID: "UTC"),
        ]
        let totals = HomeMetrics.periodTotals(transactions: txs, period: period)
        #expect(totals.income == dec("1000"))
        #expect(totals.expense == dec("200"))
    }
}
