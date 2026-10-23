//
//  ExportView.swift
//  Pocket Ledger
//
//  Export data: a CSV of transactions (with a date-range choice) or a full
//  JSON backup of everything. Both go out through the system share sheet; the
//  app never writes exports anywhere else. The heavy lifting is in the pure
//  CSVExporter / JSONBackup services — this view only gathers data and shares.
//

import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    // All rows (no soft-delete filter): CSV filters itself; the JSON backup
    // intentionally includes soft-deleted rows so a restore is complete.
    @Query private var wallets: [Wallet]
    @Query private var categories: [Category]
    @Query private var transactions: [Transaction]
    @Query private var recurringRules: [RecurringRule]
    @Query private var budgets: [Budget]
    @Query private var goals: [Goal]
    @Query private var goalEntries: [GoalEntry]
    @Query private var settingsList: [AppSettings]

    enum RangeChoice: Hashable { case all, thisYear, custom }

    @State private var rangeChoice: RangeChoice = .all
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }

    private var csvRange: ClosedRange<Date>? {
        let cal = Calendar.current
        switch rangeChoice {
        case .all:
            return nil
        case .thisYear:
            let startOfYear = cal.date(from: cal.dateComponents([.year], from: .now)) ?? .now
            return startOfYear...Date.now
        case .custom:
            let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            return min(startDate, end)...max(startDate, end)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                csvSection
                backupSection
                Section {
                    Text("Exports open the share sheet so you can save or send the file. Amounts keep full precision; the backup includes everything for a future restore.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
            .navigationTitle("Export data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(items: [url])
            }
            .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    private var csvSection: some View {
        Section("Transactions (CSV)") {
            Picker("Date range", selection: $rangeChoice) {
                Text("All time").tag(RangeChoice.all)
                Text("This year").tag(RangeChoice.thisYear)
                Text("Custom").tag(RangeChoice.custom)
            }
            if rangeChoice == .custom {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            Button {
                exportCSV()
            } label: {
                Label("Export CSV", systemImage: "tablecells")
            }
        }
    }

    private var backupSection: some View {
        Section("Full backup (JSON)") {
            Button {
                exportJSON()
            } label: {
                Label("Export full backup", systemImage: "externaldrive")
            }
            Text("Every wallet, category, transaction, budget and goal — the format a future restore will read.")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: Actions

    private func exportCSV() {
        let data = CSVExporter.csvData(transactions: transactions, currencyCode: currencyCode, range: csvRange)
        write(data, name: "pocket-ledger-\(todayStamp()).csv")
    }

    private func exportJSON() {
        let backup = JSONBackup.make(
            settings: settingsList.first,
            wallets: wallets,
            categories: categories,
            transactions: transactions,
            recurringRules: recurringRules,
            budgets: budgets,
            goals: goals,
            goalEntries: goalEntries
        )
        do {
            let data = try JSONBackup.encode(backup)
            write(data, name: "pocket-ledger-backup-\(todayStamp()).json")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func write(_ data: Data, name: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            shareURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func todayStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

/// Lets a `URL` drive a `.sheet(item:)`.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Minimal UIKit share-sheet bridge (no third-party dependency).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
