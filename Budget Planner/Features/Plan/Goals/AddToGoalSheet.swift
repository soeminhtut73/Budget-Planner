//
//  AddToGoalSheet.swift
//  Pocket Ledger
//
//  Add to or withdraw from a goal. A deposit reserves money (Total unchanged,
//  Available down); a withdrawal releases it (Available up). When Available
//  would go low the sheet warns but still allows the deposit.
//

import SwiftUI
import SwiftData

struct AddToGoalSheet: View {
    enum Mode { case deposit, withdraw }

    let goal: Goal
    let mode: Mode
    var onCompleted: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Wallet> { $0.deletedAt == nil }, sort: \Wallet.sortOrder)
    private var wallets: [Wallet]
    @Query(filter: #Predicate<Transaction> { $0.deletedAt == nil })
    private var transactions: [Transaction]
    @Query(filter: #Predicate<Goal> { $0.deletedAt == nil })
    private var goals: [Goal]
    @Query private var settingsList: [AppSettings]

    @State private var amount = AmountInput(minorUnits: 2)
    @State private var wallet: Wallet?
    @State private var showWalletPicker = false
    @State private var didConfigure = false

    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }
    private var available: Decimal {
        let total = BalanceService.totalBalance(wallets: wallets, transactions: transactions)
        let reserved = BalanceService.reserved(goals: goals.filter { $0.status != .archived })
        return total - reserved
    }
    private var resultingAvailable: Decimal {
        mode == .deposit ? available - amount.value : available + amount.value
    }
    private var title: LocalizedStringKey { mode == .deposit ? "Add to goal" : "Withdraw" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(mode == .deposit ? String(localized: "Add") : String(localized: "Withdraw")) · \(money.currencyCode)")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                    AmountText(amount: amount.value, style: .neutral,
                               tint: amount.value == 0 ? Theme.secondaryText : nil)
                        .font(.system(size: 40, weight: .bold))
                }

                Button { showWalletPicker = true } label: {
                    HStack {
                        Text(mode == .deposit ? "From wallet" : "To wallet").foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text(wallet?.name ?? "—").fontWeight(.semibold).foregroundStyle(Theme.text)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                HStack {
                    Text("This leaves").foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(money.string(resultingAvailable)) available")
                        .fontWeight(.semibold)
                        .foregroundStyle(resultingAvailable < 0 ? Theme.expense : Theme.text)
                }
                .font(.subheadline)
                .padding(.horizontal, 4)

                Spacer()
                NumberPad(allowsDecimal: money.minorUnits > 0) { handleKey($0) }
            }
            .padding()
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(amount.value <= 0)
                }
            }
            .sheet(isPresented: $showWalletPicker) {
                WalletPickerView(wallets: wallets, selection: $wallet)
            }
            .onAppear(perform: configure)
        }
    }

    private func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        amount = AmountInput(minorUnits: money.minorUnits)
        wallet = wallets.first
    }

    private func handleKey(_ key: NumberPadKey) {
        switch key {
        case .digit(let d): amount.tapDigit(d)
        case .dot: amount.tapDot()
        case .delete: amount.tapDelete()
        }
    }

    private func save() {
        let service = GoalService(context: context)
        do {
            if mode == .deposit {
                let completed = try service.deposit(goal, amount: amount.value, wallet: wallet)
                dismiss()
                if completed { onCompleted() }
            } else {
                try service.withdraw(goal, amount: amount.value, wallet: wallet)
                dismiss()
            }
        } catch {
            assertionFailure("Goal entry failed: \(error)")
        }
    }
}
