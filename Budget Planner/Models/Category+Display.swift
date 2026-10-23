//
//  Category+Display.swift
//  Pocket Ledger
//
//  Display helpers for category names. Default categories localize through the
//  String Catalog; custom categories show the name the user typed.
//

import SwiftUI

extension Category {
    /// Resolved, human-readable name. Default categories localize through the
    /// String Catalog ("category.<key>"); if a key is missing it falls back to a
    /// title-cased version of the key so the UI never shows a raw identifier.
    /// Custom categories show the name the user typed.
    ///
    /// Note: this resolves via the app's current language (not the SwiftUI
    /// environment locale). Do NOT build a `LocalizedStringKey` by interpolating
    /// the key — interpolation turns it into a format string and the lookup fails.
    var displayName: String {
        if let defaultKey {
            let key = "category.\(defaultKey)"
            let localized = Localization.string(key)
            if localized != key { return localized }
            // Fallback: "other_income" → "Other income", "bills" → "Bills".
            return defaultKey.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return customName ?? ""
    }
}
