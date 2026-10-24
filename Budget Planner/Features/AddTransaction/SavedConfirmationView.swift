//
//  SavedConfirmationView.swift
//  Pocket Ledger
//
//  Bottom card shown after a successful save: mascot placeholder, the logged
//  amount, "category · wallet", and "Add another". Auto-dismisses after ~2s,
//  dismisses on tap outside, and respects Reduce Motion (no slide, static pose).
//

import SwiftUI

struct SavedConfirmationView: View {
    let summary: TransactionService.SavedSummary
    let onAddAnother: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(MascotController.self) private var mascot

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            card
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
        }
        .animation(reduceMotion ? nil : .snappy, value: summary.amount)
        .task {
            try? await Task.sleep(for: .seconds(2))
            onDismiss()
        }
    }

    private var card: some View {
        VStack(spacing: 24) {
            MascotView(controller: mascot, size: 132)

            HStack(spacing: 8) {
                Text("Logged")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.text)
                AmountText(amount: summary.amount, kind: summary.kind)
                    .font(.title.weight(.bold))
            }

            Text("\(summary.categoryName) · \(summary.walletName)")
                .font(.body)
                .foregroundStyle(Theme.secondaryText)

            Button(action: onAddAnother) {
                Text("Add another")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(Theme.text)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 44)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    SavedConfirmationView(
        summary: .init(amount: Decimal(string: "12.50")!, kind: .expense, categoryName: "Food", walletName: "Cash"),
        onAddAnother: {},
        onDismiss: {}
    )
    .environment(MascotController())
}
