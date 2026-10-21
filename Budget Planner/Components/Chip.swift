//
//  Chip.swift
//  Pocket Ledger
//
//  A pill-shaped selectable chip. Selected chips fill with the primary color.
//  Used for income sources and Activity filters.
//

import SwiftUI

struct Chip<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let label: Label

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.isSelected = isSelected
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Theme.text)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(isSelected ? Theme.primary : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

extension Chip where Label == Text {
    init(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) {
        self.init(isSelected: isSelected, action: action) { Text(title) }
    }
}
