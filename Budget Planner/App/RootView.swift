//
//  RootView.swift
//  Pocket Ledger
//
//  Placeholder root for Phase A (data layer + components). The real tab bar
//  (Home · Activity · Plan · Reports) arrives in Phase B.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                MascotView(size: 72)
                Text("Pocket Ledger")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(verbatim: "Foundation ready")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)

                #if DEBUG
                Text(verbatim: "\(transactions.count) transactions in store")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                Button("Load sample data") {
                    try? SampleData.generate(context: context)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                #endif
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container(sampleCount: 0))
}
