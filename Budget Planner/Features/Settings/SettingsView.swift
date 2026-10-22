//
//  SettingsView.swift
//  Pocket Ledger
//
//  Phase B Settings: mostly placeholder rows. Wallets is wired to a simple
//  list. A DEBUG section exposes "Load sample data".
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]
    @State private var showCurrency = false

    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    Button {
                        showCurrency = true
                    } label: {
                        HStack {
                            Label("Currency", systemImage: "dollarsign.circle").foregroundStyle(Theme.text)
                            Spacer()
                            Text(currencyCode).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    placeholderRow("Language", systemImage: "character.bubble")
                    placeholderRow("Budget month starts", systemImage: "calendar")
                }
                Section("Your money") {
                    NavigationLink {
                        WalletsListView()
                    } label: {
                        Label("Wallets", systemImage: "wallet.pass")
                    }
                    placeholderRow("Categories", systemImage: "square.grid.2x2")
                }
                Section("App") {
                    placeholderRow("Notifications", systemImage: "bell")
                    placeholderRow("Face ID lock", systemImage: "faceid")
                    placeholderRow("Export data", systemImage: "square.and.arrow.up")
                }

                #if DEBUG
                Section("Developer") {
                    Button {
                        try? SampleData.generate(context: context)
                    } label: {
                        Label("Load sample data", systemImage: "wand.and.stars")
                    }
                    Button(role: .destructive) {
                        try? SampleData.clearTransactions(context: context)
                    } label: {
                        Label("Clear transactions", systemImage: "trash")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Change currency", isPresented: $showCurrency, titleVisibility: .visible) {
                ForEach(AppCurrencies.supported, id: \.self) { code in
                    if code != currencyCode {
                        Button(code) { changeCurrency(to: code) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Existing amounts won't be converted. Only the currency label changes.")
            }
        }
    }

    private func changeCurrency(to code: String) {
        guard let settings = settingsList.first else { return }
        settings.mainCurrency = code
        settings.updatedAt = .now
        try? context.save()
    }

    private func placeholderRow(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text("Soon").font(.footnote).foregroundStyle(Theme.secondaryText)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container(sampleCount: 0))
}
