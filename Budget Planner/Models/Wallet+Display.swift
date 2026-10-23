//
//  Wallet+Display.swift
//  Pocket Ledger
//
//  Display helpers for wallets. Each wallet type maps to an SF Symbol so the
//  wallet can be shown with an icon (e.g. in the Add transaction chip row)
//  without storing a per-wallet icon.
//

import SwiftUI

extension WalletType {
    /// SF Symbol used to represent this wallet type in the UI.
    var iconName: String {
        switch self {
        case .cash: return "banknote.fill"
        case .bank: return "building.columns.fill"
        case .eWallet: return "creditcard.fill"
        case .other: return "wallet.pass.fill"
        }
    }
}

extension Wallet {
    /// SF Symbol for this wallet, derived from its type.
    var iconName: String { type.iconName }
}
