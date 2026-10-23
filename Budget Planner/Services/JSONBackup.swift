//
//  JSONBackup.swift
//  Pocket Ledger
//
//  Full, versioned JSON backup of every model. This is the contract a future
//  import / restore and the V2 server migration will read, so it is complete
//  and stable:
//    - `schemaVersion` guards forward compatibility.
//    - Money is encoded as a string to preserve exact Decimal precision.
//    - Dates are ISO-8601 (UTC).
//    - Relationships are encoded as UUID references, not nested objects.
//    - Soft-deleted rows are included (a backup must be able to restore them).
//

import Foundation

enum JSONBackup {
    static let schemaVersion = 1

    // MARK: Root

    struct Backup: Codable, Equatable {
        var schemaVersion: Int
        var exportedAt: Date
        var appSettings: AppSettingsDTO?
        var wallets: [WalletDTO]
        var categories: [CategoryDTO]
        var transactions: [TransactionDTO]
        var recurringRules: [RecurringRuleDTO]
        var budgets: [BudgetDTO]
        var budgetLimits: [BudgetLimitDTO]
        var goals: [GoalDTO]
        var goalEntries: [GoalEntryDTO]
    }

    // MARK: DTOs

    struct WalletDTO: Codable, Equatable {
        var id: UUID
        var name: String
        var type: String
        var openingBalance: String
        var sortOrder: Int
        var isArchived: Bool
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct CategoryDTO: Codable, Equatable {
        var id: UUID
        var kind: String
        var defaultKey: String?
        var customName: String?
        var iconName: String
        var sortOrder: Int
        var isArchived: Bool
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct TransactionDTO: Codable, Equatable {
        var id: UUID
        var kind: String
        var amount: String
        var occurredAt: Date
        var timeZoneID: String
        var note: String?
        var walletID: UUID?
        var categoryID: UUID?
        var paidFromGoalID: UUID?
        var recurringRuleID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct RecurringRuleDTO: Codable, Equatable {
        var id: UUID
        var kind: String
        var amount: String
        var note: String?
        var frequency: String
        var dayOfMonth: Int
        var nextOccurrence: Date
        var isActive: Bool
        var walletID: UUID?
        var categoryID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct BudgetDTO: Codable, Equatable {
        var id: UUID
        var alertAt80: Bool
        var isArchived: Bool
        var categoryID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct BudgetLimitDTO: Codable, Equatable {
        var id: UUID
        var amount: String
        var effectiveFrom: Date
        var budgetID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct GoalDTO: Codable, Equatable {
        var id: UUID
        var name: String
        var iconName: String
        var targetAmount: String
        var targetDate: Date?
        var reminderEnabled: Bool
        var status: String
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    struct GoalEntryDTO: Codable, Equatable {
        var id: UUID
        var kind: String
        var amount: String
        var occurredAt: Date
        var timeZoneID: String
        var note: String?
        var goalID: UUID?
        var walletID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }

    // MARK: Build

    static func make(
        settings: AppSettings?,
        wallets: [Wallet],
        categories: [Category],
        transactions: [Transaction],
        recurringRules: [RecurringRule],
        budgets: [Budget],
        goals: [Goal],
        goalEntries: [GoalEntry],
        exportedAt: Date = .now
    ) -> Backup {
        Backup(
            schemaVersion: schemaVersion,
            exportedAt: exportedAt,
            appSettings: settings.map(dto(for:)),
            wallets: wallets.map(dto(for:)),
            categories: categories.map(dto(for:)),
            transactions: transactions.map(dto(for:)),
            recurringRules: recurringRules.map(dto(for:)),
            budgets: budgets.map(dto(for:)),
            budgetLimits: budgets.flatMap { ($0.limits ?? []).map(dto(for:)) },
            goals: goals.map(dto(for:)),
            goalEntries: goalEntries.map(dto(for:))
        )
    }

    // MARK: Encode / decode

    /// ISO-8601 with fractional seconds, so timestamps keep millisecond
    /// precision across a round-trip (plain `.iso8601` drops sub-second digits).
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func encode(_ backup: Backup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateFormatter.string(from: date))
        }
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = dateFormatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(string)")
            }
            return date
        }
        return try decoder.decode(Backup.self, from: data)
    }

    // MARK: Model → DTO

    private static func dto(for s: AppSettings) -> AppSettingsDTO {
        AppSettingsDTO(
            id: s.id, mainCurrency: s.mainCurrency, language: s.language,
            budgetStartDay: s.budgetStartDay, currencyChosen: s.currencyChosen,
            notifyBudgetAlerts: s.notifyBudgetAlerts, notifyGoalReminders: s.notifyGoalReminders,
            notifyRecurringPosted: s.notifyRecurringPosted, faceIDLock: s.faceIDLock,
            createdAt: s.createdAt, updatedAt: s.updatedAt, deletedAt: s.deletedAt
        )
    }

    private static func dto(for w: Wallet) -> WalletDTO {
        WalletDTO(
            id: w.id, name: w.name, type: w.type.rawValue, openingBalance: "\(w.openingBalance)",
            sortOrder: w.sortOrder, isArchived: w.isArchived,
            createdAt: w.createdAt, updatedAt: w.updatedAt, deletedAt: w.deletedAt
        )
    }

    private static func dto(for c: Category) -> CategoryDTO {
        CategoryDTO(
            id: c.id, kind: c.kind.rawValue, defaultKey: c.defaultKey, customName: c.customName,
            iconName: c.iconName, sortOrder: c.sortOrder, isArchived: c.isArchived,
            createdAt: c.createdAt, updatedAt: c.updatedAt, deletedAt: c.deletedAt
        )
    }

    private static func dto(for t: Transaction) -> TransactionDTO {
        TransactionDTO(
            id: t.id, kind: t.kind.rawValue, amount: "\(t.amount)", occurredAt: t.occurredAt,
            timeZoneID: t.timeZoneID, note: t.note, walletID: t.wallet?.id, categoryID: t.category?.id,
            paidFromGoalID: t.paidFromGoal?.id, recurringRuleID: t.recurringRule?.id,
            createdAt: t.createdAt, updatedAt: t.updatedAt, deletedAt: t.deletedAt
        )
    }

    private static func dto(for r: RecurringRule) -> RecurringRuleDTO {
        RecurringRuleDTO(
            id: r.id, kind: r.kind.rawValue, amount: "\(r.amount)", note: r.note,
            frequency: r.frequency.rawValue, dayOfMonth: r.dayOfMonth, nextOccurrence: r.nextOccurrence,
            isActive: r.isActive, walletID: r.wallet?.id, categoryID: r.category?.id,
            createdAt: r.createdAt, updatedAt: r.updatedAt, deletedAt: r.deletedAt
        )
    }

    private static func dto(for b: Budget) -> BudgetDTO {
        BudgetDTO(
            id: b.id, alertAt80: b.alertAt80, isArchived: b.isArchived, categoryID: b.category?.id,
            createdAt: b.createdAt, updatedAt: b.updatedAt, deletedAt: b.deletedAt
        )
    }

    private static func dto(for l: BudgetLimit) -> BudgetLimitDTO {
        BudgetLimitDTO(
            id: l.id, amount: "\(l.amount)", effectiveFrom: l.effectiveFrom, budgetID: l.budget?.id,
            createdAt: l.createdAt, updatedAt: l.updatedAt, deletedAt: l.deletedAt
        )
    }

    private static func dto(for g: Goal) -> GoalDTO {
        GoalDTO(
            id: g.id, name: g.name, iconName: g.iconName, targetAmount: "\(g.targetAmount)",
            targetDate: g.targetDate, reminderEnabled: g.reminderEnabled, status: g.status.rawValue,
            createdAt: g.createdAt, updatedAt: g.updatedAt, deletedAt: g.deletedAt
        )
    }

    private static func dto(for e: GoalEntry) -> GoalEntryDTO {
        GoalEntryDTO(
            id: e.id, kind: e.kind.rawValue, amount: "\(e.amount)", occurredAt: e.occurredAt,
            timeZoneID: e.timeZoneID, note: e.note, goalID: e.goal?.id, walletID: e.wallet?.id,
            createdAt: e.createdAt, updatedAt: e.updatedAt, deletedAt: e.deletedAt
        )
    }

    struct AppSettingsDTO: Codable, Equatable {
        var id: UUID
        var mainCurrency: String
        var language: String
        var budgetStartDay: Int
        var currencyChosen: Bool
        var notifyBudgetAlerts: Bool
        var notifyGoalReminders: Bool
        var notifyRecurringPosted: Bool
        var faceIDLock: Bool
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
    }
}
