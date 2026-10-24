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

/// Picks the day of the month the budget period starts on (1–28). Shows a live
/// example of the resulting date range, updating as the day is tapped.
struct BudgetStartDayView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]

    @State private var selectedDay = 1
    @State private var didInit = false

    private var settings: AppSettings? { settingsList.first }
    private var timeZoneID: String { TimeZone.current.identifier }

    /// The current period's inclusive date range for the selected start day,
    /// e.g. "25 Oct – 24 Nov".
    private var exampleRange: String {
        let period = PeriodCalculator.period(for: .now, startDay: selectedDay, timeZoneID: timeZoneID)
        let calendar = PeriodCalculator.calendar(timeZoneID: timeZoneID)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(period.start.formatted(style)) – \(lastDay.formatted(style))"
    }

    var body: some View {
        VStack(spacing: 0) {
            exampleHeader
            List {
                Section {
                    ForEach(BudgetStartDay.range, id: \.self) { day in
                        Button {
                            setDay(day)
                        } label: {
                            HStack {
                                Text(BudgetStartDay.ordinal(day)).foregroundStyle(Theme.text)
                                Spacer()
                                if selectedDay == day {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.primary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Budgets run from this day to the day before it next month. Changing it takes effect right away.")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Budget month starts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didInit { selectedDay = settings?.budgetStartDay ?? 1; didInit = true }
        }
    }

    /// Pinned example that stays visible while the day list scrolls.
    private var exampleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUR BUDGET MONTH").font(.caption).foregroundStyle(Theme.secondaryText)
            Text(exampleRange).font(.headline).foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .animation(.snappy, value: selectedDay)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func setDay(_ day: Int) {
        selectedDay = day
        guard let settings else { return }
        settings.budgetStartDay = day
        settings.updatedAt = .now
        try? context.save()
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
