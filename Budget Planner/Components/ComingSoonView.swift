//
//  ComingSoonView.swift
//  Pocket Ledger
//
//  Placeholder screen for features that arrive in later milestones.
//

import SwiftUI

struct ComingSoonView: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text("Coming soon")
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

#Preview {
    ComingSoonView(title: "Plan", systemImage: "chart.pie.fill")
}
