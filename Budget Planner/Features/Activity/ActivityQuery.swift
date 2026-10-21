//
//  ActivityQuery.swift
//  Pocket Ledger
//
//  Fetches Activity rows with cursor pagination and computes per-day totals
//  from a separate aggregate pass (never by summing the loaded page).
//
//  SwiftData's #Predicate type-checker can't handle the full filter expression
//  in reasonable time, so the DB predicate is kept to the (indexable) month
//  range and the remaining filters — kind, wallet, category, free-text search —
//  plus the cursor slice are applied in memory. A month is bounded, so this is
//  correct and cheap; the List still renders lazily from the paged slice.
//
//  The cursor is (occurredAt, createdAt) descending — UUIDs are not orderable,
//  and createdAt is a stable tiebreak when two records share an instant.
//

import Foundation
import SwiftData

enum ActivityKindFilter: Equatable {
    case all, income, expense
}

struct ActivityFilters: Equatable {
    /// Any date within the selected month.
    var month: Date = .now
    var kind: ActivityKindFilter = .all
    var walletID: UUID?
    var categoryID: UUID?
    var searchText: String = ""
}

struct TransactionCursor: Equatable {
    let occurredAt: Date
    let createdAt: Date
}

@MainActor
struct ActivityQuery {
    let context: ModelContext
    var timeZoneID: String = TimeZone.current.identifier

    /// [start, end) of the filter's month in the current time zone.
    func monthRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        let comps = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: comps) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date
        return (start, end)
    }

    /// One page of rows (newest first), after `cursor`.
    func page(
        filters: ActivityFilters,
        matchedCategoryIDs: [UUID],
        after cursor: TransactionCursor?,
        limit: Int = 50
    ) throws -> [Transaction] {
        let rows = try filteredMonth(filters: filters, matchedCategoryIDs: matchedCategoryIDs)
        return Array(applyingCursor(rows, after: cursor).prefix(limit))
    }

    /// All matching rows (no paging) — used to compute day totals.
    func allMatching(filters: ActivityFilters, matchedCategoryIDs: [UUID]) throws -> [Transaction] {
        try filteredMonth(filters: filters, matchedCategoryIDs: matchedCategoryIDs)
    }

    // MARK: Private

    /// The month's non-deleted rows (DB), filtered by kind/wallet/category/search
    /// (in memory), sorted newest first.
    private func filteredMonth(filters: ActivityFilters, matchedCategoryIDs: [UUID]) throws -> [Transaction] {
        var rows = try monthRows(for: filters.month)

        if let walletID = filters.walletID {
            rows = rows.filter { $0.wallet?.id == walletID }
        }
        if let categoryID = filters.categoryID {
            rows = rows.filter { $0.category?.id == categoryID }
        }
        switch filters.kind {
        case .all: break
        case .income: rows = rows.filter { $0.kind == .income }
        case .expense: rows = rows.filter { $0.kind == .expense }
        }

        let term = filters.searchText.trimmingCharacters(in: .whitespaces)
        if !term.isEmpty {
            let matched = Set(matchedCategoryIDs)
            rows = rows.filter { tx in
                if let note = tx.note, note.localizedCaseInsensitiveContains(term) { return true }
                if let id = tx.category?.id, matched.contains(id) { return true }
                return false
            }
        }
        return rows
    }

    private func monthRows(for date: Date) throws -> [Transaction] {
        let range = monthRange(for: date)
        let start = range.start
        let end = range.end
        let predicate = #Predicate<Transaction> { tx in
            tx.deletedAt == nil && tx.occurredAt >= start && tx.occurredAt < end
        }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.occurredAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        return try context.fetch(descriptor)
    }

    private func applyingCursor(_ rows: [Transaction], after cursor: TransactionCursor?) -> [Transaction] {
        guard let cursor else { return rows }
        return rows.filter { tx in
            tx.occurredAt < cursor.occurredAt
                || (tx.occurredAt == cursor.occurredAt && tx.createdAt < cursor.createdAt)
        }
    }
}
