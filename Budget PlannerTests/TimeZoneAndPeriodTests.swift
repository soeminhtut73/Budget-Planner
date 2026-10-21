//
//  TimeZoneAndPeriodTests.swift
//  Budget PlannerTests
//
//  Which day/month a record belongs to is decided in its local time zone, and
//  budget period boundaries follow the configured start day.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Time zones and budget periods")
struct TimeZoneAndPeriodTests {

    @Test("00:30 on 1 Nov in Yangon counts in November, not October")
    func midnightCrossoverYangon() {
        // 31 Oct 18:00 UTC == 1 Nov 00:30 in Asia/Yangon (UTC+6:30).
        let instant = utcDate(year: 2025, month: 10, day: 31, hour: 18, minute: 0)

        let yangon = PeriodCalculator.localComponents(of: instant, timeZoneID: "Asia/Yangon")
        #expect(yangon.month == 11)
        #expect(yangon.day == 1)
        #expect(yangon.hour == 0)
        #expect(yangon.minute == 30)

        // Sanity: in UTC the same instant is still 31 October.
        let utc = PeriodCalculator.localComponents(of: instant, timeZoneID: "UTC")
        #expect(utc.month == 10)
        #expect(utc.day == 31)

        // With the default start day (1), the period is November in Yangon.
        let period = PeriodCalculator.period(for: instant, startDay: 1, timeZoneID: "Asia/Yangon")
        #expect(period.contains(instant))
        let startComps = PeriodCalculator.localComponents(of: period.start, timeZoneID: "Asia/Yangon")
        #expect(startComps.month == 11)
        #expect(startComps.day == 1)
    }

    @Test("Budget start day 25 → period runs 25 Oct to 24 Nov")
    func startDay25() {
        let tz = "Asia/Yangon"
        // A date on 26 Oct local falls in the 25 Oct–24 Nov period.
        let late = utcDate(year: 2025, month: 10, day: 26, hour: 5)  // ~11:30 local
        let period = PeriodCalculator.period(for: late, startDay: 25, timeZoneID: tz)

        let start = PeriodCalculator.localComponents(of: period.start, timeZoneID: tz)
        let end = PeriodCalculator.localComponents(of: period.end, timeZoneID: tz)
        #expect(start.day == 25 && start.month == 10)   // 25 Oct inclusive
        #expect(end.day == 25 && end.month == 11)        // 25 Nov exclusive (so 24 Nov is last day)
        #expect(period.contains(late))
    }

    @Test("Before the start day, the previous period still governs")
    func beforeStartDayUsesPreviousPeriod() {
        let tz = "Asia/Yangon"
        // 24 Oct is before the 25th, so it belongs to the 25 Sep–24 Oct period.
        let early = utcDate(year: 2025, month: 10, day: 24, hour: 5)
        let period = PeriodCalculator.period(for: early, startDay: 25, timeZoneID: tz)

        let start = PeriodCalculator.localComponents(of: period.start, timeZoneID: tz)
        let end = PeriodCalculator.localComponents(of: period.end, timeZoneID: tz)
        #expect(start.day == 25 && start.month == 9)    // 25 Sep
        #expect(end.day == 25 && end.month == 10)         // 25 Oct
    }

    @Test("Start day is clamped to 1...28")
    func startDayClamped() {
        #expect(PeriodCalculator.normalizedStartDay(0) == 1)
        #expect(PeriodCalculator.normalizedStartDay(31) == 28)
        #expect(PeriodCalculator.normalizedStartDay(15) == 15)
    }
}
