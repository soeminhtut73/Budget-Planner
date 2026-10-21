//
//  GoalMath.swift
//  Pocket Ledger
//
//  Pure goal arithmetic shared by BalanceService (for reserved/Available) now
//  and GoalService later. Saved = deposits − withdrawals − amounts spent.
//

import Foundation

enum GoalMath {
    /// Saved amount from a set of entries (ignores soft-deleted ones).
    static func saved(entries: [GoalEntry]) -> Decimal {
        entries.reduce(Decimal(0)) { running, entry in
            guard entry.deletedAt == nil else { return running }
            switch entry.kind {
            case .deposit:  return running + entry.amount
            case .withdraw: return running - entry.amount
            case .spend:    return running - entry.amount
            }
        }
    }

    /// Saved amount for a goal.
    static func saved(for goal: Goal) -> Decimal {
        saved(entries: goal.entries ?? [])
    }
}
