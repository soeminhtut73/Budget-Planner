//
//  GoalEntry.swift
//  Pocket Ledger
//
//  A single movement against a goal: a deposit, a withdrawal, or a spend
//  (an expense paid from the goal). Like transactions, it stores UTC
//  `occurredAt` plus the local `timeZoneID`.
//

import Foundation
import SwiftData

@Model
final class GoalEntry {
    var id: UUID = UUID()
    var kind: GoalEntryKind = GoalEntryKind.deposit
    var amount: Decimal = 0
    var occurredAt: Date = Date.now
    var timeZoneID: String = TimeZone.current.identifier
    var note: String?

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var goal: Goal?
    /// The wallet the money came from / returns to (optional).
    var wallet: Wallet?

    init(
        id: UUID = UUID(),
        kind: GoalEntryKind = .deposit,
        amount: Decimal = 0,
        occurredAt: Date = .now,
        timeZoneID: String = TimeZone.current.identifier,
        note: String? = nil,
        goal: Goal? = nil,
        wallet: Wallet? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.occurredAt = occurredAt
        self.timeZoneID = timeZoneID
        self.note = note
        self.goal = goal
        self.wallet = wallet
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
