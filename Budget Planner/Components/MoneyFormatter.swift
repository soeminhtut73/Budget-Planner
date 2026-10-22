//
//  MoneyFormatter.swift
//  Pocket Ledger
//
//  The single place that formats money. It carries the app's currency (from
//  AppSettings) and is injected through the environment as `\.money`. It
//  formats the MAGNITUDE only — the +/− sign is added by AmountText. Uses the
//  narrow symbol ("$", not "US$"); symbol position and digits come from the
//  Locale and the currency's standard minor units.
//

import SwiftUI

struct MoneyFormatter {
    let currencyCode: String

    var minorUnits: Int { CurrencyInfo.minorUnits(for: currencyCode) }

    /// Format style for editable money fields (TextField value bindings).
    var currencyStyle: Decimal.FormatStyle.Currency {
        .currency(code: currencyCode).presentation(.narrow)
    }

    /// Full amount, e.g. "$1,800.00", "15,000 Ks", "25,000 ₫".
    func string(_ amount: Decimal, locale: Locale = .current) -> String {
        amount.formatted(.currency(code: currencyCode).presentation(.narrow).locale(locale))
    }

    /// Compact amount for tight spots only (wallet chips, chart labels),
    /// e.g. "$1.8K", "1.5M Ks", "25M ₫".
    func compact(_ amount: Decimal, locale: Locale = .current) -> String {
        amount.formatted(.currency(code: currencyCode).presentation(.narrow).notation(.compactName).locale(locale))
    }
}

private struct MoneyFormatterKey: EnvironmentKey {
    static let defaultValue = MoneyFormatter(currencyCode: "USD")
}

extension EnvironmentValues {
    var money: MoneyFormatter {
        get { self[MoneyFormatterKey.self] }
        set { self[MoneyFormatterKey.self] = newValue }
    }
}
