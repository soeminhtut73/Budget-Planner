//
//  Theme.swift
//  Pocket Ledger
//
//  Single source of truth for app UI colors. Values live in the Asset
//  Catalog with light/dark variants; this type exposes them by role.
//  Always pair color with a sign or label — never rely on color alone.
//

import SwiftUI

enum Theme {
    /// Primary brand color. Also used for income amounts.
    static let primary = Color("BrandPrimary")
    /// Income amounts (same hue as primary, named for intent at call sites).
    static let income = Color("BrandPrimary")
    /// Expense amounts.
    static let expense = Color("Expense")
    /// Warnings, e.g. "Over 80%".
    static let warning = Color("Warning")

    static let background = Color("Background")
    static let surface = Color("Surface")
    static let text = Color("TextPrimary")
    static let secondaryText = Color("TextSecondary")
    static let border = Color("Border")

    /// Minimum touch target per the design guidelines.
    static let minTouchTarget: CGFloat = 44
}
