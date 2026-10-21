//
//  DefaultData.swift
//  Pocket Ledger
//
//  The default wallets and categories seeded on first launch. Category names
//  are localized via `category.<key>` in the String Catalog; `key` is also the
//  stable `defaultKey` used by exports.
//

import Foundation

struct DefaultCategoryDef {
    let key: String        // stored as Category.defaultKey; localization key is "category.<key>"
    let kind: CategoryKind
    let icon: String       // SF Symbol
}

struct DefaultWalletDef {
    let nameKey: String    // String Catalog key, e.g. "wallet.cash"
    let type: WalletType
}

enum DefaultData {
    static let expenseCategories: [DefaultCategoryDef] = [
        .init(key: "food",      kind: .expense, icon: "fork.knife"),
        .init(key: "transport", kind: .expense, icon: "car.fill"),
        .init(key: "shopping",  kind: .expense, icon: "bag.fill"),
        .init(key: "bills",     kind: .expense, icon: "doc.text.fill"),
        .init(key: "rent",      kind: .expense, icon: "house.fill"),
        .init(key: "health",    kind: .expense, icon: "cross.case.fill"),
        .init(key: "fun",       kind: .expense, icon: "gamecontroller.fill"),
        .init(key: "other",     kind: .expense, icon: "ellipsis.circle.fill"),
    ]

    static let incomeCategories: [DefaultCategoryDef] = [
        .init(key: "salary",       kind: .income, icon: "banknote.fill"),
        .init(key: "allowance",    kind: .income, icon: "dollarsign.circle.fill"),
        .init(key: "freelance",    kind: .income, icon: "laptopcomputer"),
        .init(key: "gift",         kind: .income, icon: "gift.fill"),
        .init(key: "other_income", kind: .income, icon: "plus.circle.fill"),
    ]

    static var allCategories: [DefaultCategoryDef] { expenseCategories + incomeCategories }

    static let wallets: [DefaultWalletDef] = [
        .init(nameKey: "wallet.cash",    type: .cash),
        .init(nameKey: "wallet.bank",    type: .bank),
        .init(nameKey: "wallet.ewallet", type: .eWallet),
    ]
}
