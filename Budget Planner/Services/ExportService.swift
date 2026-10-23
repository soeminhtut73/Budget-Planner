//
//  ExportService.swift
//  Pocket Ledger
//
//  CSV export of transactions. Money keeps full Decimal precision (never
//  rounded, never formatted through MoneyFormatter). Each record's local date
//  and time are derived from its own `occurredAt` + `timeZoneID`, so a record
//  always appears on the calendar day it happened in the user's zone.
//
//  The CSV uses stable English headers and a `category_key` column so a future
//  importer / server migration has a machine-readable contract. It is encoded
//  UTF-8 with a BOM so Excel renders Burmese text correctly.
//

import Foundation

enum CSVExporter {
    /// Stable, machine-readable header row (do not localize — this is the
    /// re-import contract). `category` is localized for the user; `category_key`
    /// is the stable identifier for default categories (empty for custom ones).
    static let header = [
        "local_date", "local_time", "type", "category", "category_key",
        "wallet", "amount", "currency", "note", "paid_from_goal",
    ]

    /// Builds the CSV text (without BOM) for the given transactions.
    /// - Parameters:
    ///   - transactions: records to export (soft-deleted ones are skipped).
    ///   - currencyCode: the app's main currency, written in the `currency` column.
    ///   - range: optional inclusive date range filter on `occurredAt`.
    static func csv(
        transactions: [Transaction],
        currencyCode: String,
        range: ClosedRange<Date>? = nil
    ) -> String {
        let rows = transactions
            .filter { $0.deletedAt == nil }
            .filter { range?.contains($0.occurredAt) ?? true }
            .sorted { $0.occurredAt > $1.occurredAt }

        var lines = [row(header)]
        for tx in rows {
            lines.append(row(fields(for: tx, currencyCode: currencyCode)))
        }
        return lines.joined(separator: "\r\n")
    }

    /// The CSV encoded as UTF-8 **with a BOM**, for file export / Excel.
    static func csvData(
        transactions: [Transaction],
        currencyCode: String,
        range: ClosedRange<Date>? = nil
    ) -> Data {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let body = csv(transactions: transactions, currencyCode: currencyCode, range: range)
        return bom + Data(body.utf8)
    }

    // MARK: Field building

    private static func fields(for tx: Transaction, currencyCode: String) -> [String] {
        let zone = TimeZone(identifier: tx.timeZoneID) ?? .current
        return [
            dateString(tx.occurredAt, zone: zone),
            timeString(tx.occurredAt, zone: zone),
            tx.kind.rawValue,
            tx.category?.displayName ?? "",
            tx.category?.defaultKey ?? "",
            tx.wallet?.name ?? "",
            // Full-precision Decimal, locale-independent (period separator).
            "\(tx.amount)",
            currencyCode,
            tx.note ?? "",
            tx.paidFromGoal?.name ?? "",
        ]
    }

    // MARK: Date formatting (local to each record's time zone)

    private static func dateString(_ date: Date, zone: TimeZone) -> String {
        formatter(format: "yyyy-MM-dd", zone: zone).string(from: date)
    }

    private static func timeString(_ date: Date, zone: TimeZone) -> String {
        formatter(format: "HH:mm", zone: zone).string(from: date)
    }

    private static func formatter(format: String, zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = zone
        f.dateFormat = format
        return f
    }

    // MARK: RFC 4180 encoding

    /// Joins one record's fields, quoting any that contain a comma, quote, or
    /// newline, and doubling embedded quotes.
    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"")
            || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
