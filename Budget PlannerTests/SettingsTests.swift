//
//  SettingsTests.swift
//  Budget PlannerTests
//
//  Small helpers behind the Settings functions: the budget-start-day ordinal
//  label and the language display-name lookup.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Settings")
struct SettingsTests {

    @Test("Budget start day is shown as a localized ordinal")
    func startDayOrdinal() {
        // Ordinals use the current locale; en gives 1st / 2nd / 25th.
        #expect(BudgetStartDay.ordinal(1) == "1st")
        #expect(BudgetStartDay.ordinal(2) == "2nd")
        #expect(BudgetStartDay.ordinal(25) == "25th")
    }

    @Test("Start-day range is 1...28")
    func startDayRange() {
        #expect(BudgetStartDay.range.lowerBound == 1)
        #expect(BudgetStartDay.range.upperBound == 28)
    }

    @Test("Language display names resolve, with a fallback for unknown codes")
    func languageNames() {
        #expect(AppLanguages.name(for: "en") == "English")
        #expect(AppLanguages.name(for: "my") == "မြန်မာ")
        #expect(AppLanguages.name(for: "zz") == "zz")   // unknown → the code itself
    }

    @Test("Localization returns the key when no translation exists")
    func localizationFallback() {
        Localization.languageCode = "en"
        let missing = "definitely.not.a.real.key"
        #expect(Localization.string(missing) == missing)
    }
}
