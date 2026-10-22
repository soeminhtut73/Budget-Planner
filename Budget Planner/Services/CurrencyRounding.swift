//
//  CurrencyRounding.swift
//  Pocket Ledger
//
//  Money is stored and summed as full-precision Decimal. Rounding to a
//  currency's minor units happens ONLY for display. Never round before
//  storing or before arithmetic.
//

import Foundation

enum CurrencyRounding {
    /// Number of fractional digits a currency shows (its minor units), derived
    /// from the currency's standard (see `CurrencyInfo`).
    static func minorUnits(for currencyCode: String) -> Int {
        CurrencyInfo.minorUnits(for: currencyCode)
    }

    /// Rounds `amount` to the currency's minor units (half up). For DISPLAY only.
    static func rounded(_ amount: Decimal, currencyCode: String) -> Decimal {
        rounded(amount, scale: minorUnits(for: currencyCode))
    }

    /// Rounds `amount` to `scale` fractional digits (half up, away from zero).
    static func rounded(_ amount: Decimal, scale: Int) -> Decimal {
        var input = amount
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }
}
