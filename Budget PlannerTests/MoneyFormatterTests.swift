//
//  MoneyFormatterTests.swift
//  Budget PlannerTests
//
//  Money formatting: decimals follow the currency's standard, the narrow symbol
//  is used (never "US$"), and a compact style exists for tight spots. Run in
//  both en and my locales.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Money formatter")
struct MoneyFormatterTests {
    private let en = Locale(identifier: "en_US")
    private let my = Locale(identifier: "my_MM")

    @Test("USD always shows 2 decimals")
    func usdDecimals() {
        let usd = MoneyFormatter(currencyCode: "USD")
        #expect(usd.string(1800, locale: en) == "$1,800.00")
        #expect(usd.string(dec("4.50"), locale: en) == "$4.50")
    }

    @Test("MMK and VND show no decimals")
    func zeroDecimalCurrencies() {
        let mmk = MoneyFormatter(currencyCode: "MMK").string(15000, locale: en)
        let vnd = MoneyFormatter(currencyCode: "VND").string(25000, locale: en)
        #expect(mmk.contains("15,000"))
        #expect(!mmk.contains("."))
        #expect(vnd.contains("25,000"))
        #expect(!vnd.contains("."))
    }

    @Test("Output never contains US$ (narrow symbol), in en or my")
    func neverUSD() {
        let usd = MoneyFormatter(currencyCode: "USD")
        #expect(!usd.string(1800, locale: en).contains("US$"))
        #expect(!usd.string(1800, locale: my).contains("US$"))
    }

    @Test("Minor units come from the currency's standard")
    func minorUnits() {
        #expect(MoneyFormatter(currencyCode: "USD").minorUnits == 2)
        #expect(MoneyFormatter(currencyCode: "MMK").minorUnits == 0)
        #expect(MoneyFormatter(currencyCode: "VND").minorUnits == 0)
    }

    @Test("Compact style shortens large amounts")
    func compactLarge() {
        let mmk = MoneyFormatter(currencyCode: "MMK")
        let full = mmk.string(1_500_000, locale: en)
        let compact = mmk.compact(1_500_000, locale: en)
        #expect(compact.count < full.count)
        #expect(compact.uppercased().contains("M"))

        let vnd = MoneyFormatter(currencyCode: "VND")
        #expect(vnd.compact(25_000_000, locale: en).uppercased().contains("M"))
    }

    @Test("In my locale, a USD amount still uses the narrow symbol")
    func burmeseLocale() {
        let usd = MoneyFormatter(currencyCode: "USD").string(1800, locale: my)
        #expect(!usd.contains("US$"))
    }
}
