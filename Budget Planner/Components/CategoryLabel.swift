//
//  CategoryLabel.swift
//  Pocket Ledger
//
//  Renders a category's name, localizing default categories through the String
//  Catalog (so it follows the environment locale) and showing the typed name
//  for custom ones.
//

import SwiftUI

struct CategoryLabel: View {
    let category: Category

    var body: some View {
        if let titleKey = category.titleKey {
            Text(titleKey)
        } else {
            Text(category.customName ?? "")
        }
    }
}
