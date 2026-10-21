//
//  ActivityViewModel.swift
//  Pocket Ledger
//
//  Drives the Activity list: filters, cursor paging, day grouping and delete.
//  Day totals come from a separate aggregate pass, so a day's header total is
//  correct even when that day's rows are split across pages.
//

import Foundation
import SwiftData
import Observation

/// A day's rows plus its net total (income − expense) for the header.
struct ActivityDaySection: Identifiable {
    let id: Int            // local-day key (yyyymmdd)
    let date: Date         // start-of-day, for header formatting
    let net: Decimal
    var items: [Transaction]
}

@MainActor
@Observable
final class ActivityViewModel {
    var filters: ActivityFilters {
        didSet { if filters != oldValue { reload() } }
    }

    private(set) var sections: [ActivityDaySection] = []
    private(set) var isLoading = false
    private(set) var reachedEnd = false

    let currencyCode: String
    private(set) var wallets: [Wallet] = []
    /// The category the list is pinned to (when opened from Budget detail).
    private(set) var pinnedCategory: Category?

    private let context: ModelContext
    private let query: ActivityQuery
    private let timeZoneID = TimeZone.current.identifier
    private var allCategories: [Category] = []

    private var cursor: TransactionCursor?
    private var loadedItems: [Transaction] = []
    private var dayTotals: [Int: Decimal] = [:]

    init(context: ModelContext, initialWalletID: UUID? = nil, initialCategoryID: UUID? = nil) {
        self.context = context
        self.query = ActivityQuery(context: context)

        let settings = try? SwiftDataAppSettingsRepository(context: context).current()
        self.currencyCode = settings?.mainCurrency ?? "USD"

        let categoryRepo = SwiftDataCategoryRepository(context: context)
        self.allCategories = (try? categoryRepo.allCategories()) ?? []
        self.wallets = (try? SwiftDataWalletRepository(context: context).activeWallets()) ?? []
        self.filters = ActivityFilters(month: .now, kind: .all, walletID: initialWalletID, categoryID: initialCategoryID)
        self.pinnedCategory = allCategories.first { $0.id == initialCategoryID }
        reload()
    }

    // MARK: Loading

    func reload() {
        cursor = nil
        loadedItems = []
        reachedEnd = false
        let matched = matchedCategoryIDs()
        let all = (try? query.allMatching(filters: filters, matchedCategoryIDs: matched)) ?? []
        dayTotals = computeDayTotals(all)
        loadNextPage()
    }

    func loadNextPage() {
        guard !isLoading, !reachedEnd else { return }
        isLoading = true
        defer { isLoading = false }

        let matched = matchedCategoryIDs()
        let page = (try? query.page(filters: filters, matchedCategoryIDs: matched, after: cursor, limit: 50)) ?? []
        loadedItems.append(contentsOf: page)
        if let last = page.last {
            cursor = TransactionCursor(occurredAt: last.occurredAt, createdAt: last.createdAt)
        }
        if page.count < 50 { reachedEnd = true }
        rebuildSections()
    }

    /// Call as rows appear to page in ~10 rows from the bottom.
    func onRowAppear(_ transaction: Transaction) {
        guard let index = loadedItems.firstIndex(where: { $0.id == transaction.id }) else { return }
        if index >= loadedItems.count - 10 {
            loadNextPage()
        }
    }

    // MARK: Mutations

    func setWalletFilter(_ id: UUID?) {
        filters.walletID = id
    }

    func delete(_ transaction: Transaction) {
        try? TransactionService(context: context).delete(transaction)
        reload()
    }

    // MARK: Helpers

    private func matchedCategoryIDs() -> [UUID] {
        let term = filters.searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return [] }
        return allCategories
            .filter { $0.displayName.localizedCaseInsensitiveContains(term) }
            .map(\.id)
    }

    private func dayKey(for date: Date, timeZoneID: String) -> Int {
        let c = PeriodCalculator.localComponents(of: date, timeZoneID: timeZoneID)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    private func computeDayTotals(_ transactions: [Transaction]) -> [Int: Decimal] {
        var totals: [Int: Decimal] = [:]
        for tx in transactions {
            let key = dayKey(for: tx.occurredAt, timeZoneID: tx.timeZoneID)
            let signed = tx.kind == .income ? tx.amount : -tx.amount
            totals[key, default: 0] += signed
        }
        return totals
    }

    private func rebuildSections() {
        var order: [Int] = []
        var grouped: [Int: [Transaction]] = [:]
        for tx in loadedItems {
            let key = dayKey(for: tx.occurredAt, timeZoneID: tx.timeZoneID)
            if grouped[key] == nil { order.append(key); grouped[key] = [] }
            grouped[key]?.append(tx)
        }
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        sections = order.map { key in
            let items = grouped[key] ?? []
            let date = items.first.map { startOfLocalDay(of: $0.occurredAt, timeZoneID: $0.timeZoneID, calendar: calendar) } ?? .now
            return ActivityDaySection(id: key, date: date, net: dayTotals[key] ?? 0, items: items)
        }
    }

    private func startOfLocalDay(of date: Date, timeZoneID: String, calendar: Calendar) -> Date {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: timeZoneID) ?? cal.timeZone
        return cal.startOfDay(for: date)
    }
}
