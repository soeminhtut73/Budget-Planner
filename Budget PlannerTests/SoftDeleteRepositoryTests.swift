//
//  SoftDeleteRepositoryTests.swift
//  Budget PlannerTests
//
//  Verifies the SwiftData repositories persist records and that soft delete
//  hides them from reads (the record stays in the store, recoverable later).
//

import Testing
import Foundation
import SwiftData
@testable import Budget_Planner

@MainActor
@Suite("SwiftData repositories — soft delete")
struct SoftDeleteRepositoryTests {

    private func makeContext() throws -> ModelContext {
        let container = try AppSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test("Inserted wallet is fetched; soft delete hides it from reads")
    func softDeleteWallet() throws {
        let repo = SwiftDataWalletRepository(context: try makeContext())
        let wallet = Wallet(name: "Cash", openingBalance: dec("100"))
        repo.insert(wallet)
        try repo.save()

        #expect(try repo.activeWallets().count == 1)

        repo.softDelete(wallet)
        try repo.save()

        #expect(wallet.deletedAt != nil)            // still in the store
        #expect(try repo.activeWallets().isEmpty)   // hidden from reads
        #expect(try repo.allWallets().isEmpty)
    }

    @Test("Archived wallets are excluded from activeWallets but kept in allWallets")
    func archivedWalletFiltering() throws {
        let repo = SwiftDataWalletRepository(context: try makeContext())
        let active = Wallet(name: "Cash")
        let archived = Wallet(name: "Old", isArchived: true)
        repo.insert(active)
        repo.insert(archived)
        try repo.save()

        #expect(try repo.activeWallets().map(\.name) == ["Cash"])
        #expect(try repo.allWallets().count == 2)
    }

    @Test("Goal status filtering: activeGoals excludes archived")
    func goalStatusFiltering() throws {
        let repo = SwiftDataGoalRepository(context: try makeContext())
        repo.insert(Goal(name: "Trip", status: .active))
        repo.insert(Goal(name: "Done", status: .archived))
        try repo.save()

        #expect(try repo.activeGoals().map(\.name) == ["Trip"])
        #expect(try repo.allGoals().count == 2)
    }
}
