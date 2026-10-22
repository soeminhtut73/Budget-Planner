//
//  AmountText.swift
//  Pocket Ledger
//
//  Renders a money amount with its sign and semantic color. The sign is always
//  shown, so meaning never depends on color alone. Currency formatting comes
//  from the injected `\.money` formatter — callers never pass a currency code.
//

import SwiftUI

enum AmountStyle {
    case income    // shown with a leading "+"
    case expense   // shown with a leading "−" (U+2212)
    case neutral   // no forced sign (e.g. a balance); keeps the value's own sign

    init(kind: TransactionKind) {
        self = (kind == .income) ? .income : .expense
    }
}

struct AmountText: View {
    let amount: Decimal
    let style: AmountStyle
    /// Overrides the semantic color (e.g. white on the dark balance card).
    var tint: Color?

    @Environment(\.money) private var money
    @Environment(\.locale) private var locale

    init(amount: Decimal, style: AmountStyle, tint: Color? = nil) {
        self.amount = amount
        self.style = style
        self.tint = tint
    }

    /// Convenience for a transaction's amount + kind.
    init(amount: Decimal, kind: TransactionKind, tint: Color? = nil) {
        self.init(amount: amount, style: AmountStyle(kind: kind), tint: tint)
    }

    var body: some View {
        Text(formatted)
            .foregroundStyle(tint ?? defaultColor)
    }

    private var formatted: String {
        switch style {
        case .income:
            return "+ " + money.string(amount.magnitude, locale: locale)
        case .expense:
            return "\u{2212} " + money.string(amount.magnitude, locale: locale)
        case .neutral:
            return amount < 0
                ? "\u{2212}" + money.string(amount.magnitude, locale: locale)
                : money.string(amount, locale: locale)
        }
    }

    private var defaultColor: Color {
        switch style {
        case .income:  return Theme.income
        case .expense: return Theme.expense
        case .neutral: return Theme.text
        }
    }
}

#Preview("USD") {
    VStack(alignment: .trailing, spacing: 8) {
        AmountText(amount: 1800, style: .income)
        AmountText(amount: Decimal(string: "4.50")!, style: .expense)
        AmountText(amount: 5480, style: .neutral)
    }
    .font(.title2.weight(.semibold)).padding()
    .environment(\.money, MoneyFormatter(currencyCode: "USD"))
}

#Preview("MMK") {
    VStack(alignment: .trailing, spacing: 8) {
        AmountText(amount: 1800, style: .income)
        AmountText(amount: 15000, style: .expense)
        AmountText(amount: 320000, style: .neutral)
    }
    .font(.title2.weight(.semibold)).padding()
    .environment(\.money, MoneyFormatter(currencyCode: "MMK"))
}
