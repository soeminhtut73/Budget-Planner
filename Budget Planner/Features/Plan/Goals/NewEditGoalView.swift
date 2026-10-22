//
//  NewEditGoalView.swift
//  Pocket Ledger
//
//  Create or edit a savings goal: name, icon, target amount, optional target
//  date, monthly reminder, and (on create) an optional starting amount set
//  aside from a wallet. Setting money aside never changes Total balance.
//

import SwiftUI
import SwiftData

struct NewEditGoalView: View {
    var editingGoal: Goal?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Wallet> { $0.deletedAt == nil }, sort: \Wallet.sortOrder)
    private var wallets: [Wallet]
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query(filter: #Predicate<Goal> { $0.deletedAt == nil })
    private var goals: [Goal]
    @Query private var settingsList: [AppSettings]
    @Environment(\.money) private var money

    @State private var name = ""
    @State private var iconName = "target"
    @State private var target: Decimal = 0
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 4, to: .now) ?? .now
    @State private var reminder = false
    @State private var startingAmount: Decimal = 0
    @State private var sourceWallet: Wallet?
    @State private var didConfigure = false

    private let icons = ["target", "airplane", "house.fill", "car.fill", "gift.fill",
                         "graduationcap.fill", "heart.fill", "gamecontroller.fill"]

    private var isEditing: Bool { editingGoal != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && target > 0 }
    private var available: Decimal {
        let total = BalanceService.totalBalance(wallets: wallets, transactions: transactions)
        let reserved = BalanceService.reserved(goals: goals.filter { $0.status != .archived })
        return total - reserved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    field("NAME") {
                        TextField("e.g. Trip to Vietnam", text: $name)
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                    field("ICON") { iconPicker }
                    detailsCard
                    if !isEditing { startWithCard }
                    previewCard
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(isEditing ? "Edit goal" : "New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create goal") { save() }
                        .fontWeight(.semibold).disabled(!canSave)
                }
            }
            .onAppear(perform: configure)
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    private var iconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    Button { iconName = icon } label: {
                        CategoryIcon(systemName: icon, size: 44)
                            .overlay(Circle().stroke(iconName == icon ? Theme.primary : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Target amount").foregroundStyle(Theme.secondaryText)
                Spacer()
                TextField("0", value: $target, format: money.currencyStyle)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .fontWeight(.semibold).foregroundStyle(Theme.text)
            }
            Divider()
            Toggle("Set a target date", isOn: $hasTargetDate).tint(Theme.primary)
            if hasTargetDate {
                DatePicker("Target date", selection: $targetDate, in: Date.now..., displayedComponents: .date)
            }
            Divider()
            Toggle("Monthly reminder", isOn: $reminder).tint(Theme.primary)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var startWithCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("START WITH (OPTIONAL)").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            HStack {
                Text("Amount").foregroundStyle(Theme.secondaryText)
                Spacer()
                TextField("0", value: $startingAmount, format: money.currencyStyle)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .fontWeight(.semibold).foregroundStyle(Theme.text)
            }
            Divider()
            Picker("Set aside from", selection: $sourceWallet) {
                ForEach(wallets) { wallet in Text(wallet.name).tag(wallet as Wallet?) }
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var previewCard: some View {
        let start = isEditing ? 0 : startingAmount
        let remainingAfterStart = max(0, target - start)
        let months = hasTargetDate ? GoalMath.monthsRemaining(to: targetDate) : 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("PLAN").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            if hasTargetDate, months > 0 {
                HStack {
                    Text("Save each month").foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(money.string(remainingAfterStart / Decimal(months))) × \(months) months")
                        .fontWeight(.semibold).foregroundStyle(Theme.text)
                }
            }
            HStack {
                Text("Total balance").foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("No change").fontWeight(.semibold).foregroundStyle(Theme.text)
            }
            if !isEditing, start > 0 {
                HStack {
                    Text("Available to spend").foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(money.string(available)) → \(money.string(available - start))")
                        .foregroundStyle(Theme.text)
                }
            }
        }
        .font(.subheadline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.border.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Logic

    private func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        sourceWallet = wallets.first
        if let goal = editingGoal {
            name = goal.name
            iconName = goal.iconName
            target = goal.targetAmount
            if let date = goal.targetDate { hasTargetDate = true; targetDate = date }
            reminder = goal.reminderEnabled
        }
    }

    private func save() {
        let service = GoalService(context: context)
        let date = hasTargetDate ? targetDate : nil
        do {
            if let goal = editingGoal {
                try service.update(goal, name: name, iconName: iconName, target: target, targetDate: date, reminder: reminder)
            } else {
                try service.createGoal(name: name, iconName: iconName, target: target, targetDate: date,
                                       reminder: reminder, startingAmount: startingAmount, sourceWallet: sourceWallet)
            }
            dismiss()
        } catch {
            assertionFailure("Save goal failed: \(error)")
        }
    }
}
