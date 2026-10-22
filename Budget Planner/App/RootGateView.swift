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

    var body: some View {
        Group {
            if settings?.currencyChosen == true {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.money, MoneyFormatter(currencyCode: currencyCode))
    }
}

#Preview {
    RootGateView().modelContainer(PreviewData.container(sampleCount: 0))
}
