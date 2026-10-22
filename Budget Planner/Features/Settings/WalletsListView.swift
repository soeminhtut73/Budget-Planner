//
//  WalletsListView.swift
//  Pocket Ledger
//
//  A simple list of wallets with their current balances. (Full wallet CRUD
//  arrives with the Settings milestone.)
//

import SwiftUI
import SwiftData

struct WalletsListView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Wallet> { $0.deletedAt == nil }, sort: \Wallet.sortOrder)
    private var wallets: [Wallet]
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]

    private var currencyCode: String {
        (try? SwiftDataAppSettingsRepository(context: context).current())?.mainCurrency ?? "USD"
    }

    var body: some View {
        List(wallets) { wallet in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.name).foregroundStyle(Theme.text)
                    Text(wallet.type.rawValue.capitalized)
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                AmountText(
                    amount: BalanceService.walletBalance(wallet, transactions: transactions),
                    style: .neutral
                )
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("Wallets")
    }
}

#Preview {
    NavigationStack {
        WalletsListView()
            .modelContainer(PreviewData.container())
    }
}
