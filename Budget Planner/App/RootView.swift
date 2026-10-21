//
//  RootView.swift
//  Pocket Ledger
//
//  Placeholder root for Milestone 1 (data layer only). The real tab bar
//  (Home · Activity · Plan · Reports) arrives in later milestones.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Pocket Ledger")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text("Foundation ready")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

#Preview {
    RootView()
}
