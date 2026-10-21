//
//  AmountFormatter.swift
//  Pocket Ledger
//
//  Pure, testable money formatting. Amounts are stored as positive Decimals;
//  `AmountStyle` decides the sign and (in the view) the color. Formatting uses
//  the given Locale and the currency's own minor units (USD 2dp, MMK 0dp).
//

import Foundation

enum AmountStyle {
    case income    // shown with a leading "+"
    case expense   // shown with a leading "−" (U+2212)
    case neutral   // no forced sign (e.g. a balance); keeps the value's own sign

    init(kind: TransactionKind) {
        self = (kind == .income) ? .income : .expense
    }
}

enum AmountFormatter {
    /// Signed, currency-formatted string, e.g. "+ $1,800.00" or "− $4.50".
    static func signedString(
        amount: Decimal,
        style: AmountStyle,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        let format = Decimal.FormatStyle.Currency(code: currencyCode, locale: locale)
        switch style {
        case .neutral:
            return amount.formatted(format)
        case .income:
            return "+ " + amount.magnitude.formatted(format)
        case .expense:
            return "\u{2212} " + amount.magnitude.formatted(format)
        }
    }
}
