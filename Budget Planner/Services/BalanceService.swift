//
//  BalanceService.swift
//  Pocket Ledger
//
//  The core money rules, as pure functions over model objects:
//   • Wallet balance = opening + income − expenses (for that wallet).
//   • Total balance  = sum of all wallet balances (real money).
//   • Reserved       = sum of goals' saved amounts (goals reserve, don't move).
//   • Available      = Total − Reserved.
//  Every expense reduces Total, including expenses paid from a goal. Goal
//  deposits never change Total; they increase Reserved.
//

import Foundation

enum BalanceService {
    /// Wallet balance: opening balance adjusted by that wallet's non-deleted
    /// income and expenses. Goal-paid expenses are included (they reduce Total).
    static func walletBalance(_ wallet: Wallet, transactions: [Transaction]) -> Decimal {
        transactions.reduce(wallet.openingBalance) { running, tx in
            guard tx.deletedAt == nil, tx.wallet?.id == wallet.id else { return running }
            switch tx.kind {
            case .income:  return running + tx.amount
            case .expense: return running - tx.amount
            }
        }
    }

    /// Total balance = sum of the given wallets' balances. Pass all non-deleted
    /// wallets. This is real money.
    static func totalBalance(wallets: [Wallet], transactions: [Transaction]) -> Decimal {
        wallets.reduce(Decimal(0)) { $0 + walletBalance($1, transactions: transactions) }
    }

    /// Reserved money = sum of saved amounts across the given goals. Pass the
    /// non-archived goals whose reservations are still held.
    static func reserved(goals: [Goal]) -> Decimal {
        goals.reduce(Decimal(0)) { $0 + GoalMath.saved(for: $1) }
    }

    /// Available = Total − Reserved.
    static func available(total: Decimal, reserved: Decimal) -> Decimal {
        total - reserved
    }

    /// Convenience: Available computed directly from wallets, transactions and goals.
    static func available(wallets: [Wallet], transactions: [Transaction], goals: [Goal]) -> Decimal {
        available(
            total: totalBalance(wallets: wallets, transactions: transactions),
            reserved: reserved(goals: goals)
        )
    }
}
