//
//  ExportTests.swift
//  Budget PlannerTests
//
//  Export round-trip tests: CSV and JSON must preserve exact Decimal amounts
//  and Burmese text, derive the local day from each record's own time zone,
//  escape correctly, write a BOM, and honor the date-range filter.
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Export")
struct ExportTests {

    // MARK: Helpers

    /// Splits a CSV body (no BOM) into rows of fields, honoring RFC-4180 quotes.
    /// Works over Unicode scalars so CRLF (a single Swift `Character`) is handled.
    private func parse(_ csv: String) -> [[String]] {
        // Normalize line endings to "\n" first, then treat only "\n" as a break.
        let normalized = csv
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let scalars = Array(normalized.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = Character(scalars[i])
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count && Character(scalars[i + 1]) == "\"" {
                        field.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": record.append(field); field = ""
                case "\n":
                    record.append(field); field = ""; rows.append(record); record = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty { record.append(field); rows.append(record) }
        return rows
    }

    private func col(_ header: [String], _ name: String) -> Int {
        header.firstIndex(of: name)!
    }

    // MARK: CSV

    @Test("CSV round-trip keeps exact Decimal amounts and Burmese text")
    func csvRoundTrip() {
        let wallet = Wallet(name: "Cash", type: .cash)
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let custom = Budget_Planner.Category(kind: .expense, customName: "စားသောက်ဆိုင်") // "restaurant" in Burmese
        let tx1 = Transaction(kind: .expense, amount: dec("12.505"),
                              occurredAt: utcDate(year: 2026, month: 10, day: 5, hour: 9),
                              timeZoneID: "UTC", note: "မနက်စာ", wallet: wallet, category: food)
        let tx2 = Transaction(kind: .expense, amount: dec("1000"),
                              occurredAt: utcDate(year: 2026, month: 10, day: 6, hour: 9),
                              timeZoneID: "UTC", wallet: wallet, category: custom)

        let csv = CSVExporter.csv(transactions: [tx1, tx2], currencyCode: "USD")
        let rows = parse(csv)
        let header = rows[0]
        #expect(header == CSVExporter.header)

        // Newest first: tx2 (Oct 6) before tx1 (Oct 5).
        let r2 = rows[1], r1 = rows[2]
        #expect(r1[col(header, "amount")] == "12.505")
        #expect(r1[col(header, "note")] == "မနက်စာ")
        #expect(r1[col(header, "category_key")] == "food")
        #expect(r2[col(header, "amount")] == "1000")
        #expect(r2[col(header, "category")] == "စားသောက်ဆိုင်")
        #expect(r2[col(header, "category_key")] == "")   // custom has no key
        #expect(r1[col(header, "currency")] == "USD")
    }

    @Test("CSV escapes commas, quotes, and newlines in notes")
    func csvEscaping() {
        let messy = "Lunch, \"deluxe\"\nwith team"
        let tx = Transaction(kind: .expense, amount: dec("5"),
                             occurredAt: utcDate(year: 2026, month: 10, day: 5), timeZoneID: "UTC", note: messy)
        let csv = CSVExporter.csv(transactions: [tx], currencyCode: "USD")
        let rows = parse(csv)
        #expect(rows[1][col(rows[0], "note")] == messy)
    }

    @Test("CSV data starts with a UTF-8 BOM")
    func csvBOM() {
        let data = CSVExporter.csvData(transactions: [], currencyCode: "USD")
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    @Test("Local date comes from the record's own time zone, not UTC")
    func csvLocalDateByZone() {
        // 2026-11-01 00:30 Asia/Yangon == 2026-10-31 18:00 UTC. Must show November 1.
        let utc = utcDate(year: 2026, month: 10, day: 31, hour: 18, minute: 0)
        let tx = Transaction(kind: .expense, amount: dec("1"), occurredAt: utc, timeZoneID: "Asia/Yangon")
        let csv = CSVExporter.csv(transactions: [tx], currencyCode: "MMK")
        let rows = parse(csv)
        let header = rows[0]
        #expect(rows[1][col(header, "local_date")] == "2026-11-01")
        #expect(rows[1][col(header, "local_time")] == "00:30")
    }

    @Test("Date range filters which transactions are exported")
    func csvDateRange() {
        let inRange = Transaction(kind: .expense, amount: dec("1"),
                                  occurredAt: utcDate(year: 2026, month: 10, day: 10), timeZoneID: "UTC")
        let outRange = Transaction(kind: .expense, amount: dec("2"),
                                   occurredAt: utcDate(year: 2026, month: 9, day: 10), timeZoneID: "UTC")
        let start = utcDate(year: 2026, month: 10, day: 1)
        let end = utcDate(year: 2026, month: 10, day: 31, hour: 23, minute: 59)
        let csv = CSVExporter.csv(transactions: [inRange, outRange], currencyCode: "USD", range: start...end)
        let rows = parse(csv)
        #expect(rows.count == 2)   // header + one row
        #expect(rows[1][col(rows[0], "amount")] == "1")
    }

    @Test("Soft-deleted transactions are excluded from CSV")
    func csvSkipsDeleted() {
        let live = Transaction(kind: .expense, amount: dec("1"),
                               occurredAt: utcDate(year: 2026, month: 10, day: 10), timeZoneID: "UTC")
        let deleted = Transaction(kind: .expense, amount: dec("2"),
                                  occurredAt: utcDate(year: 2026, month: 10, day: 11), timeZoneID: "UTC",
                                  deletedAt: .now)
        let csv = CSVExporter.csv(transactions: [live, deleted], currencyCode: "USD")
        #expect(parse(csv).count == 2)
    }

    // MARK: JSON

    @Test("JSON backup round-trips every model with exact amounts and text")
    func jsonRoundTrip() throws {
        let wallet = Wallet(name: "Bank", type: .bank, openingBalance: dec("500.25"))
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let goal = Goal(name: "ခရီးစဉ်", targetAmount: dec("1000")) // "trip"
        let tx = Transaction(kind: .expense, amount: dec("12.505"),
                             occurredAt: utcDate(year: 2026, month: 10, day: 5, hour: 9),
                             timeZoneID: "Asia/Yangon", note: "မှတ်စု",
                             wallet: wallet, category: food, paidFromGoal: goal)
        let budget = Budget(category: food)
        let limit = BudgetLimit(amount: dec("400"), effectiveFrom: utcDate(year: 2026, month: 10, day: 1), budget: budget)
        budget.limits = [limit]
        let entry = GoalEntry(kind: .deposit, amount: dec("100.50"),
                              occurredAt: utcDate(year: 2026, month: 10, day: 2), timeZoneID: "Asia/Yangon",
                              goal: goal, wallet: wallet)

        let backup = JSONBackup.make(
            settings: nil, wallets: [wallet], categories: [food], transactions: [tx],
            recurringRules: [], budgets: [budget], goals: [goal], goalEntries: [entry]
        )
        let data = try JSONBackup.encode(backup)
        let decoded = try JSONBackup.decode(data)

        // Full round-trip: re-encoding the decoded backup reproduces the bytes
        // (both truncate timestamps identically), so every field survived.
        #expect(try JSONBackup.encode(decoded) == data)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.transactions.count == 1)
        #expect(Decimal(string: decoded.transactions.first!.amount) == dec("12.505"))
        #expect(decoded.transactions.first?.walletID == wallet.id)
        #expect(decoded.transactions.first?.categoryID == food.id)
        #expect(decoded.transactions.first?.paidFromGoalID == goal.id)
        #expect(Decimal(string: decoded.wallets.first!.openingBalance) == dec("500.25"))
        #expect(Decimal(string: decoded.budgetLimits.first!.amount) == dec("400"))
        #expect(decoded.budgetLimits.first?.budgetID == budget.id)
        #expect(decoded.goals.first?.name == "ခရီးစဉ်")
        #expect(Decimal(string: decoded.goalEntries.first!.amount) == dec("100.50"))
    }

    @Test("Exact Decimal values survive the JSON string encoding")
    func jsonDecimalExactness() throws {
        let tx = Transaction(kind: .expense, amount: dec("12.505"),
                             occurredAt: utcDate(year: 2026, month: 10, day: 5), timeZoneID: "UTC")
        let backup = JSONBackup.make(
            settings: nil, wallets: [], categories: [], transactions: [tx],
            recurringRules: [], budgets: [], goals: [], goalEntries: []
        )
        let decoded = try JSONBackup.decode(try JSONBackup.encode(backup))
        #expect(Decimal(string: decoded.transactions.first!.amount) == dec("12.505"))
    }
}
