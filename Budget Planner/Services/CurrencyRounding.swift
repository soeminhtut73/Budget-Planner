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
    /// Number of fractional digits a currency shows (its minor units).
    /// Southeast-Asia defaults plus common cases; unknown codes fall back to 2.
    static func minorUnits(for currencyCode: String) -> Int {
        switch currencyCode.uppercased() {
        case "MMK", "VND", "JPY", "KRW", "IDR", "LAK", "KHR": return 0
        default: return 2  // USD, SGD, THB, PHP, EUR, …
        }
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
