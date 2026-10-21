//
//  NumberPad.swift
//  Pocket Ledger
//
//  Custom keypad: 1–9, ".", 0, Delete. Calls back with each key. The "."
//  key is disabled for currencies with no minor units (e.g. MMK).
//

import SwiftUI

enum NumberPadKey: Equatable {
    case digit(Int)
    case dot
    case delete
}

struct NumberPad: View {
    let allowsDecimal: Bool
    let onKey: (NumberPadKey) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { digit in
                key(label: "\(digit)", key: .digit(digit))
            }
            key(label: ".", key: .dot, enabled: allowsDecimal)
            key(label: "0", key: .digit(0))
            Button {
                onKey(.delete)
            } label: {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(Theme.text)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
        }
    }

    private func key(label: String, key: NumberPadKey, enabled: Bool = true) -> some View {
        Button {
            onKey(key)
        } label: {
            Text(label)
                .font(.title.weight(.regular))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(enabled ? Theme.text : Theme.secondaryText.opacity(0.4))
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    NumberPad(allowsDecimal: true) { _ in }
        .padding()
        .background(Theme.background)
}
