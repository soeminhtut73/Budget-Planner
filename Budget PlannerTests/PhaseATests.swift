//
//  PhaseATests.swift
//  Budget PlannerTests
//
//  Pure amount-formatting tests. Store-backed tests live in DataStoreTests.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Amount formatting")
struct AmountFormatterTests {
    private let enUS = Locale(identifier: "en_US")

    @Test("Income shows a plus sign and 2 decimals for USD")
    func incomeUSD() {
        let s = AmountFormatter.signedString(amount: 1800, style: .income, currencyCode: "USD", locale: enUS)
        #expect(s.hasPrefix("+ "))
        #expect(s.contains("1,800.00"))
    }

    @Test("Expense shows a minus sign (U+2212)")
    func expenseUSD() {
        let s = AmountFormatter.signedString(amount: dec("4.50"), style: .expense, currencyCode: "USD", locale: enUS)
        #expect(s.hasPrefix("\u{2212} "))
        #expect(s.contains("4.50"))
    }

    @Test("MMK shows no decimal places")
    func mmkNoDecimals() {
        let s = AmountFormatter.signedString(amount: 1800, style: .income, currencyCode: "MMK", locale: enUS)
        #expect(s.hasPrefix("+ "))
        #expect(s.contains("1,800"))
        #expect(!s.contains("."))
    }

    @Test("Neutral keeps the value's own sign and adds none")
    func neutral() {
        let s = AmountFormatter.signedString(amount: 5480, style: .neutral, currencyCode: "USD", locale: enUS)
        #expect(!s.hasPrefix("+"))
        #expect(s.contains("5,480.00"))
    }
}
