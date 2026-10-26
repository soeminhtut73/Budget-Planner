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
    @State private var showLanguage = false

    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }
    private var languageCode: String { settingsList.first?.language ?? "en" }
    private var startDay: Int { settingsList.first?.budgetStartDay ?? 1 }

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
                    Button {
                        showLanguage = true
                    } label: {
                        HStack {
                            Label("Language", systemImage: "character.bubble").foregroundStyle(Theme.text)
                            Spacer()
                            Text(AppLanguages.name(for: languageCode)).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    NavigationLink {
                        BudgetStartDayView()
                    } label: {
                        HStack {
                            Label("Budget month starts", systemImage: "calendar")
                            Spacer()
                            Text(BudgetStartDay.ordinal(startDay)).foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                Section("Your money") {
                    NavigationLink {
                        WalletsListView()
                    } label: {
                        Label("Wallets", systemImage: "wallet.pass")
                    }
                    NavigationLink {
                        CategoriesListView()
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }
                }
                Section("App") {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    placeholderRow("Face ID lock", systemImage: "faceid")
                    NavigationLink {
                        ExportView()
                    } label: {
                        Label("Export data", systemImage: "square.and.arrow.up")
                    }
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
            .confirmationDialog("Change language", isPresented: $showLanguage, titleVisibility: .visible) {
                ForEach(AppLanguages.supported, id: \.code) { lang in
                    if lang.code != languageCode {
                        Button(lang.name) { changeLanguage(to: lang.code) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func changeLanguage(to code: String) {
        guard let settings = settingsList.first else { return }
        settings.language = code
        settings.updatedAt = .now
        try? context.save()
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
