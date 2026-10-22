//
//  SummaryCard.swift
//  Pocket Ledger
//
//  A simple surface card with an optional title and arbitrary content.
//  Used for the Home summary cards and elsewhere.
//

import SwiftUI

struct SummaryCard<Content: View>: View {
    private let title: LocalizedStringKey?
    private let content: Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }
}

#Preview {
    SummaryCard(title: "Total balance") {
        AmountText(amount: 5480, style: .neutral)
            .font(.largeTitle.weight(.bold))
    }
    .padding()
    .background(Theme.background)
}
