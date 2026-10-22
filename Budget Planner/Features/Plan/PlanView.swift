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
    @State private var segment: Segment = .budgets

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Plan")
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Theme.text)

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
            .background(Theme.background)
        }
    }
}

#Preview {
    PlanView().modelContainer(PreviewData.container())
}
