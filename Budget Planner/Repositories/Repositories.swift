//
//  Repositories.swift
//  Pocket Ledger
//
//  Data access goes through these protocols so a server-backed or synced
//  implementation (V2) can replace the local SwiftData one. Every read
//  excludes soft-deleted records (`deletedAt != nil`); deletes are soft.
//

import Foundation

protocol WalletRepository {
    /// Non-deleted, non-archived wallets, ordered by `sortOrder`.
    func activeWallets() throws -> [Wallet]
    /// All non-deleted wallets (including archived).
    func allWallets() throws -> [Wallet]
    func wallet(id: UUID) throws -> Wallet?
    func insert(_ wallet: Wallet)
    /// Soft delete: sets `deletedAt`; the record stays recoverable.
    func softDelete(_ wallet: Wallet)
    func save() throws
}

protocol TransactionRepository {
    /// All non-deleted transactions, newest first.
    func allTransactions() throws -> [Transaction]
    func transaction(id: UUID) throws -> Transaction?
    func insert(_ transaction: Transaction)
    func softDelete(_ transaction: Transaction)
    func save() throws
}

protocol GoalRepository {
    /// Non-deleted goals that are not archived.
    func activeGoals() throws -> [Goal]
    /// All non-deleted goals (including completed/archived).
    func allGoals() throws -> [Goal]
    func goal(id: UUID) throws -> Goal?
    func insert(_ goal: Goal)
    func softDelete(_ goal: Goal)
    func save() throws
}
