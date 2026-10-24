//
//  OnboardingView.swift
//  Pocket Ledger
//
//  First-launch currency step. Pre-selects from the device region (MM → MMK,
//  VN → VND, otherwise USD) and saves the choice to AppSettings.
//

import SwiftUI
import SwiftData

/// Supported currencies in V1. Keep this list easy to extend.
enum AppCurrencies {
    static let supported = ["MMK", "VND", "USD"]

    static func defaultForRegion(_ locale: Locale = .current) -> String {
        switch locale.region?.identifier {
        case "MM": return "MMK"
        case "VN": return "VND"
        default: return "USD"
        }
    }

    static func name(for code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var selected = AppCurrencies.defaultForRegion()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    MascotView(mood: .idle, size: 88)
                    Text("Which currency do you use?")
                        .font(.title.weight(.bold)).foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                    Text("You can change this later in Settings.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }

                VStack(spacing: 12) {
                    ForEach(AppCurrencies.supported, id: \.self) { code in
                        currencyOption(code)
                    }
                }

                Spacer()
                Button(action: save) {
                    Text("Continue")
                        .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.white).background(Theme.primary, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    private func currencyOption(_ code: String) -> some View {
        let isSelected = selected == code
        let sample = MoneyFormatter(currencyCode: code).string(1000)
        return Button { selected = code } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(code).font(.headline).foregroundStyle(Theme.text)
                    Text(AppCurrencies.name(for: code)).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Text(sample).foregroundStyle(Theme.secondaryText)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.primary : Theme.border)
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Theme.primary : Theme.border, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        do {
            let settings = try SwiftDataAppSettingsRepository(context: context).ensureDefault()
            settings.mainCurrency = selected
            settings.currencyChosen = true
            settings.updatedAt = .now
            try context.save()
        } catch {
            assertionFailure("Saving currency failed: \(error)")
        }
    }
}

#Preview {
    OnboardingView().modelContainer(PreviewData.container(sampleCount: 0))
}
