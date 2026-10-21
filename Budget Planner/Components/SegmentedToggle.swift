//
//  SegmentedToggle.swift
//  Pocket Ledger
//
//  A two-option segmented control with the selected segment filled in the
//  primary color. Used for Expense | Income (and later Budgets | Goals).
//

import SwiftUI

struct SegmentedToggle<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: LocalizedStringKey)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.18)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(isSelected ? Color.white : Theme.text)
                        .background(isSelected ? Theme.primary : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}

#Preview {
    struct Demo: View {
        @State private var kind: TransactionKind = .expense
        var body: some View {
            SegmentedToggle(selection: $kind, options: [
                (.expense, "Expense"), (.income, "Income"),
            ])
            .padding()
            .background(Theme.background)
        }
    }
    return Demo()
}
