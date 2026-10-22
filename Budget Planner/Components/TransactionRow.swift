//
//  TransactionRow.swift
//  Pocket Ledger
//
//  One transaction row: category icon, title (note, or category name if no
//  note), "Category · Wallet" subtitle, and the signed amount. Reused by Home
//  recent activity and the Activity list.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(systemName: transaction.category?.iconName ?? "tag", size: 40)

            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                subtitle
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            AmountText(amount: transaction.amount, kind: transaction.kind)
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var title: some View {
        if let note = transaction.note, !note.isEmpty {
            Text(note)
        } else if let category = transaction.category {
            CategoryLabel(category: category)
        } else {
            Text("Transaction")
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        HStack(spacing: 4) {
            if let category = transaction.category {
                CategoryLabel(category: category)
            }
            if transaction.category != nil, transaction.wallet != nil {
                Text(verbatim: "·")
            }
            if let wallet = transaction.wallet {
                Text(wallet.name)
            }
        }
    }
}
