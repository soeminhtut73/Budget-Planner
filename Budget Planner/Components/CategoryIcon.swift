//
//  CategoryIcon.swift
//  Pocket Ledger
//
//  A circular SF Symbol badge for a category or wallet. Decorative — the
//  meaningful label is provided by the surrounding row, so this is hidden
//  from accessibility.
//

import SwiftUI

struct CategoryIcon: View {
    let systemName: String
    var color: Color = Theme.primary
    var size: CGFloat = 40

    init(systemName: String, color: Color = Theme.primary, size: CGFloat = 40) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    init(category: Category, color: Color = Theme.primary, size: CGFloat = 40) {
        self.init(systemName: category.iconName, color: color, size: size)
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        CategoryIcon(systemName: "fork.knife")
        CategoryIcon(systemName: "car.fill", color: Theme.expense)
        CategoryIcon(systemName: "banknote.fill", color: Theme.income)
    }
    .padding()
}
