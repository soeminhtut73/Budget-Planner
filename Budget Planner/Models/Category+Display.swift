//
//  Category+Display.swift
//  Pocket Ledger
//
//  Display helpers for category names. Default categories localize through the
//  String Catalog; custom categories show the name the user typed.
//

import SwiftUI

extension Category {
    /// A SwiftUI-resolvable title (uses the environment locale). Nil for custom
    /// categories — use `customName` for those.
    var titleKey: LocalizedStringKey? {
        guard let defaultKey else { return nil }
        return LocalizedStringKey("category.\(defaultKey)")
    }

    /// Resolved name in the app's current language. Use for search matching and
    /// any non-`Text` context (exports, accessibility).
    var displayName: String {
        if let defaultKey {
            return NSLocalizedString("category.\(defaultKey)", comment: "default category name")
        }
        return customName ?? ""
    }
}
