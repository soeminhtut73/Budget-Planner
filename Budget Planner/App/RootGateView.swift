//
//  RootGateView.swift
//  Pocket Ledger
//
//  Shows the currency onboarding step until a currency is chosen, then the main
//  app. Injects the MoneyFormatter (from the saved currency) into the
//  environment for the whole tree — the single source of money formatting.
//

import SwiftUI
import SwiftData

struct RootGateView: View {
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }
    private var currencyCode: String { settings?.mainCurrency ?? "USD" }
    private var languageCode: String { settings?.language ?? "en" }

    var body: some View {
        Group {
            if settings?.currencyChosen == true {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.money, MoneyFormatter(currencyCode: currencyCode))
        // Apply the in-app language live: SwiftUI Text and formatting follow the
        // environment locale; Localization mirrors it for non-SwiftUI lookups.
        .environment(\.locale, Locale(identifier: languageCode))
        .id(languageCode)
        .onAppear { Localization.languageCode = languageCode }
        .onChange(of: languageCode) { _, newValue in Localization.languageCode = newValue }
    }
}

#Preview {
    RootGateView().modelContainer(PreviewData.container(sampleCount: 0))
}
