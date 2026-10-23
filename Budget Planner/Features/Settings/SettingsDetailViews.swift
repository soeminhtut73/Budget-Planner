//
//  SettingsDetailViews.swift
//  Pocket Ledger
//
//  Detail screens reached from Settings: the budget month start day (1–28) and
//  the notification toggles. Both edit the single AppSettings record directly.
//

import SwiftUI
import SwiftData

/// Formats a day-of-month as an ordinal ("1st", "25th"), localized.
enum BudgetStartDay {
    static let range = 1...28

    static func ordinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }
}

/// Picks the day of the month the budget period starts on (1–28).
struct BudgetStartDayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        List {
            Section {
                ForEach(BudgetStartDay.range, id: \.self) { day in
                    Button {
                        setDay(day)
                    } label: {
                        HStack {
                            Text(BudgetStartDay.ordinal(day)).foregroundStyle(Theme.text)
                            Spacer()
                            if settings?.budgetStartDay == day {
                                Image(systemName: "checkmark").foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }
            } footer: {
                Text("Budgets run from this day to the day before it next month. Changing it takes effect right away.")
            }
        }
        .navigationTitle("Budget month starts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setDay(_ day: Int) {
        guard let settings else { return }
        settings.budgetStartDay = day
        settings.updatedAt = .now
        try? context.save()
        dismiss()
    }
}

/// Toggles for the app's local notifications.
struct NotificationsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        List {
            Section {
                toggle("Budget alerts", isOn: bind(\.notifyBudgetAlerts))
                toggle("Goal reminders", isOn: bind(\.notifyGoalReminders))
                toggle("Recurring income posted", isOn: bind(\.notifyRecurringPosted))
            } footer: {
                Text("Alerts are delivered on this device. You can also manage permission in iOS Settings.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn).tint(Theme.primary)
    }

    /// Binds a Bool field of AppSettings, saving and (when enabling) requesting
    /// notification permission.
    private func bind(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard let settings else { return }
                settings[keyPath: keyPath] = newValue
                settings.updatedAt = .now
                try? context.save()
                if newValue { Task { await NotificationService.requestAuthorization() } }
            }
        )
    }
}
