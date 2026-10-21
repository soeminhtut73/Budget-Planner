//
//  SampleData.swift
//  Pocket Ledger
//
//  DEBUG-only generator of realistic transactions for testing paging, totals
//  and layouts. Deterministic (seeded RNG) so tests can assert on the output.
//  Compiled out of release builds.
//

#if DEBUG
import Foundation
import SwiftData

/// Small deterministic RNG (SplitMix64) so sample data is reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum SampleData {
    /// Generates `count` transactions spread over the past ~6 months. Seeds the
    /// defaults first if the store is empty.
    @MainActor
    static func generate(context: ModelContext, count: Int = 500, seed: UInt64 = 42) throws {
        try SeedService.seedIfNeeded(context: context)

        let wallets = try context.fetch(
            FetchDescriptor<Wallet>(predicate: #Predicate { $0.deletedAt == nil })
        )
        let categories = try context.fetch(
            FetchDescriptor<Category>(predicate: #Predicate { $0.deletedAt == nil })
        )
        let expenseCats = categories.filter { $0.kind == .expense }
        let incomeCats = categories.filter { $0.kind == .income }

        guard
            let anyWallet = wallets.first,
            let anyExpense = expenseCats.first,
            let anyIncome = incomeCats.first
        else { return }

        var rng = SeededGenerator(seed: seed)
        let tzID = TimeZone.current.identifier
        let now = Date.now
        let daySpan = 180

        for _ in 0..<count {
            let isIncome = Int.random(in: 0..<100, using: &rng) < 20   // ~20% income
            let kind: TransactionKind = isIncome ? .income : .expense
            let category = (isIncome ? incomeCats : expenseCats).randomElement(using: &rng)
                ?? (isIncome ? anyIncome : anyExpense)
            let wallet = wallets.randomElement(using: &rng) ?? anyWallet

            let dayOffset = Int.random(in: 0..<daySpan, using: &rng)
            let secOffset = Int.random(in: 0..<86_400, using: &rng)
            let occurredAt = now.addingTimeInterval(TimeInterval(-(dayOffset * 86_400 + secOffset)))

            let amount: Decimal
            if isIncome {
                amount = Decimal(Int.random(in: 50...3000, using: &rng))
            } else {
                let whole = Decimal(Int.random(in: 1...200, using: &rng))
                let cents = Decimal(Int.random(in: 0...99, using: &rng)) / 100
                amount = whole + cents
            }

            let tx = Transaction(
                kind: kind,
                amount: amount,
                occurredAt: occurredAt,
                timeZoneID: tzID,
                wallet: wallet,
                category: category
            )
            context.insert(tx)
        }

        try context.save()
    }

    /// Removes all transactions and recurring rules (keeps wallets, categories
    /// and settings). For resetting after loading sample data.
    @MainActor
    static func clearTransactions(context: ModelContext) throws {
        try context.delete(model: Transaction.self)
        try context.delete(model: RecurringRule.self)
        try context.save()
    }
}
#endif
