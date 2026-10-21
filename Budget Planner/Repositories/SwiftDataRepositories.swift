//
//  SwiftDataRepositories.swift
//  Pocket Ledger
//
//  SwiftData-backed implementations of the repository protocols.
//

import Foundation
import SwiftData

struct SwiftDataWalletRepository: WalletRepository {
    let context: ModelContext

    func activeWallets() throws -> [Wallet] {
        var descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func allWallets() throws -> [Wallet] {
        let descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func wallet(id: UUID) throws -> Wallet? {
        var descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ wallet: Wallet) { context.insert(wallet) }

    func softDelete(_ wallet: Wallet) {
        wallet.deletedAt = .now
        wallet.updatedAt = .now
    }

    func save() throws { try context.save() }
}

struct SwiftDataTransactionRepository: TransactionRepository {
    let context: ModelContext

    func allTransactions() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func transaction(id: UUID) throws -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ transaction: Transaction) { context.insert(transaction) }

    func softDelete(_ transaction: Transaction) {
        transaction.deletedAt = .now
        transaction.updatedAt = .now
    }

    func save() throws { try context.save() }
}

struct SwiftDataGoalRepository: GoalRepository {
    let context: ModelContext

    func activeGoals() throws -> [Goal] {
        // Status is an enum; filter it in memory to avoid enum-in-#Predicate
        // limitations. Goals are few, so this is cheap.
        try allGoals().filter { $0.status == .active }
    }

    func allGoals() throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func goal(id: UUID) throws -> Goal? {
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ goal: Goal) { context.insert(goal) }

    func softDelete(_ goal: Goal) {
        goal.deletedAt = .now
        goal.updatedAt = .now
    }

    func save() throws { try context.save() }
}
