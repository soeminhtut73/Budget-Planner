//
//  BalanceBreakdownView.swift
//  Pocket Ledger
//
//  The "Available" detail sheet, opened from the Home balance card's ⓘ button.
//  Shows how Available is reached: Total balance, each active goal's reserved
//  amount, then Available. Reserved money still sits in the user's wallets —
//  goals only set it aside — so the sheet says so explicitly.
//

import SwiftUI

struct BalanceBreakdownView: View {
    let total: Decimal
    /// Active (non-archived) goals whose reservations are still held.
    let goals: [Goal]

    @Environment(\.money) private var money
    @Environment(\.dismiss) private var dismiss

    private var reservingGoals: [(goal: Goal, saved: Decimal)] {
        goals
            .map { ($0, GoalMath.saved(for: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }
    private var reserved: Decimal { reservingGoals.reduce(Decimal(0)) { $0 + $1.saved } }
    private var available: Decimal { total - reserved }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    totalRow
                    if reservingGoals.isEmpty {
                        emptyReserved
                    } else {
                        reservedCard
                    }
                    availableCard
                    footerNote
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Available balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private var totalRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL BALANCE").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Text("All money across your wallets").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text(money.string(total)).font(.title3.weight(.bold)).foregroundStyle(Theme.text)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var reservedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RESERVED FOR GOALS").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("− \(money.string(reserved))").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
            }
            VStack(spacing: 0) {
                ForEach(Array(reservingGoals.enumerated()), id: \.element.goal.id) { index, pair in
                    HStack(spacing: 10) {
                        CategoryIcon(systemName: pair.goal.iconName, size: 22)
                        Text(pair.goal.name).font(.subheadline).foregroundStyle(Theme.text)
                        Spacer()
                        Text("− \(money.string(pair.saved))").font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 8)
                    if index < reservingGoals.count - 1 { Divider() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var emptyReserved: some View {
        HStack {
            Text("No money reserved").foregroundStyle(Theme.secondaryText)
            Spacer()
            Text("− \(money.string(0))").foregroundStyle(Theme.secondaryText)
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var availableCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AVAILABLE").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                Text("Total minus goal savings").font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Text(money.string(available)).font(.title3.weight(.bold)).foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var footerNote: some View {
        Text("Goal savings stay in your wallets — they're only set aside here, so Total doesn't change when you save toward a goal.")
            .font(.footnote).foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}
