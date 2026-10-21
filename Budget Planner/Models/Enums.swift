//
//  Enums.swift
//  Pocket Ledger
//
//  Shared enumerations used across the data model. All are String-backed
//  and Codable so SwiftData (and a future CloudKit store) can persist them,
//  and so a stable raw value can be written to CSV/JSON exports.
//

import Foundation

enum WalletType: String, Codable, CaseIterable, Sendable {
    case cash
    case bank
    case eWallet
    case other
}

enum CategoryKind: String, Codable, CaseIterable, Sendable {
    case expense
    case income
}

enum TransactionKind: String, Codable, CaseIterable, Sendable {
    case expense
    case income
}

enum Frequency: String, Codable, CaseIterable, Sendable {
    case monthly   // Only monthly in V1.
}

enum GoalEntryKind: String, Codable, CaseIterable, Sendable {
    case deposit   // money reserved toward the goal
    case withdraw  // money released back to Available
    case spend     // expense paid from the goal (reduces Total and the goal)
}

enum GoalStatus: String, Codable, CaseIterable, Sendable {
    case active
    case completed
    case archived
}
