//
//  PlanView.swift
//  Pocket Ledger
//
//  Plan tab: Budgets | Savings goals. Budgets are built here; Goals arrive in
//  the next milestone.
//

import SwiftUI
import SwiftData

struct PlanView: View {
    enum Segment: Hashable { case budgets, goals }
    @Environment(\.modelContext) private var context
    @State private var segment: Segment = .budgets
    @State private var showAddBudget = false
    @State private var showAddGoal = false
    @State private var showAddExpense = false

    var body: some View {
        NavigationStack {
            // FAB lives in the tab's root content, so a pushed detail view
            // covers it (and shows its own) — no duplicate during the push.
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 16) {
                    header

                    SegmentedToggle(selection: $segment, options: [
                        (.budgets, "Budgets"), (.goals, "Savings goals"),
                    ])

                    if segment == .budgets {
                        BudgetsListView()
                    } else {
                        GoalsListView()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Theme.background)

                addButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .sheet(isPresented: $showAddBudget) { AddEditBudgetView() }
            .sheet(isPresented: $showAddGoal) { NewEditGoalView() }
            .sheet(isPresented: $showAddExpense) { AddTransactionView(context: context) }
        }
    }

    private var addButton: some View {
        Button { showAddExpense = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.primary, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel("Add transaction")
    }

    private var header: some View {
        HStack {
            Text("Plan")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
            Spacer()
            Button {
                if segment == .budgets { showAddBudget = true } else { showAddGoal = true }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(segment == .budgets ? "Add budget" : "New goal")
        }
    }
}

#Preview {
    PlanView()
        .modelContainer(PreviewData.container())
        .environment(MascotController())
}
