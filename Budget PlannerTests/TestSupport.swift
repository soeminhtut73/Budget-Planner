//
//  TestSupport.swift
//  Budget PlannerTests
//
//  Small helpers shared across the money-engine tests.
//

import Foundation
@testable import Budget_Planner

/// Exact Decimal from a string literal (never via Double).
func dec(_ string: String) -> Decimal {
    guard let value = Decimal(string: string) else {
        fatalError("invalid decimal literal: \(string)")
    }
    return value
}

/// Builds a UTC instant from calendar components, for timezone tests.
func utcDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    guard let date = calendar.date(from: comps) else {
        fatalError("invalid date components")
    }
    return date
}
