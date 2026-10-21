//
//  AmountText.swift
//  Pocket Ledger
//
//  Renders a money amount with its sign and semantic color. The sign is always
//  shown, so meaning never depends on color alone. Currency is passed in.
//

import SwiftUI

struct AmountText: View {
    let amount: Decimal
    let style: AmountStyle
    let currencyCode: String
    /// Overrides the semantic color (e.g. white on the dark balance card).
    var tint: Color?

    @Environment(\.locale) private var locale

    init(amount: Decimal, style: AmountStyle, currencyCode: String, tint: Color? = nil) {
        self.amount = amount
        self.style = style
        self.currencyCode = currencyCode
        self.tint = tint
    }

    /// Convenience for a transaction's amount + kind.
    init(amount: Decimal, kind: TransactionKind, currencyCode: String, tint: Color? = nil) {
        self.init(amount: amount, style: AmountStyle(kind: kind), currencyCode: currencyCode, tint: tint)
    }

    var body: some View {
        Text(AmountFormatter.signedString(
            amount: amount, style: style, currencyCode: currencyCode, locale: locale
        ))
        .foregroundStyle(tint ?? defaultColor)
    }

    private var defaultColor: Color {
        switch style {
        case .income:  return Theme.income
        case .expense: return Theme.expense
        case .neutral: return Theme.text
        }
    }
}

#Preview("Light") {
    VStack(alignment: .trailing, spacing: 8) {
        AmountText(amount: 1800, style: .income, currencyCode: "USD")
        AmountText(amount: Decimal(string: "4.50")!, style: .expense, currencyCode: "USD")
        AmountText(amount: 320000, style: .neutral, currencyCode: "MMK")
    }
    .font(.title2.weight(.semibold))
    .padding()
}

#Preview("Dark") {
    VStack(alignment: .trailing, spacing: 8) {
        AmountText(amount: 1800, style: .income, currencyCode: "USD")
        AmountText(amount: Decimal(string: "4.50")!, style: .expense, currencyCode: "USD")
    }
    .font(.title2.weight(.semibold))
    .padding()
    .preferredColorScheme(.dark)
}
