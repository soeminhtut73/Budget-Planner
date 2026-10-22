//
//  CurrencyInfo.swift
//  Pocket Ledger
//
//  Derives a currency's standard minor units (fraction digits) from the
//  system's currency data rather than a hardcoded list, so adding a currency
//  later needs no code change.
//

import Foundation

enum CurrencyInfo {
    /// The currency's standard number of fraction digits (USD 2, MMK/VND 0, …).
    static func minorUnits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.maximumFractionDigits
    }
}
