//
//  CategoryLabel.swift
//  Pocket Ledger
//
//  Renders a category's resolved name (localized default, or the typed custom
//  name). Uses `displayName` rather than an interpolated LocalizedStringKey,
//  which would otherwise be mis-parsed as a format string.
//

import SwiftUI

struct CategoryLabel: View {
    let category: Category

    var body: some View {
        Text(category.displayName)
    }
}
