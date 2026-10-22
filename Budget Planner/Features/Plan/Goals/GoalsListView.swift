//
//  GoalsListView.swift
//  Pocket Ledger
//
//  Plan → Savings goals: total reserved and a card per goal (progress, saved of
//  target, date, monthly needed, Add). Goals reserve money; they don't move it.
//

import SwiftUI
import SwiftData

struct GoalsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money

    @Query(filter: #Predicate<Goal> { $0.deletedAt == nil }, sort: \Goal.createdAt)
    private var allGoals: [Goal]
    @Query private var settingsList: [AppSettings]

    @State private var showNew = false
    @State private var depositTarget: Goal?
    @State private var completedGoal: Goal?

    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }
    private var startDay: Int { settingsList.first?.budgetStartDay ?? 1 }
    private var goals: [Goal] { allGoals.filter { $0.status != .archived } }
    private var totalReserved: Decimal { BalanceService.reserved(goals: goals) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if goals.isEmpty {
                    emptyState
                } else {
                    HStack {
                        Text("TOTAL SAVED").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text(money.string(totalReserved))
                            .font(.title3.weight(.bold)).foregroundStyle(Theme.text)
                    }
                    ForEach(goals) { goal in
                        goalCard(goal)
                    }
                }
                newGoalButton
            }
            .padding(.bottom, 96)
        }
        .navigationDestination(for: Goal.self) { GoalDetailView(goal: $0) }
        .sheet(isPresented: $showNew) { NewEditGoalView() }
        .sheet(item: $depositTarget) { goal in
            AddToGoalSheet(goal: goal, mode: .deposit, onCompleted: { completedGoal = goal })
        }
        .fullScreenCover(item: $completedGoal) { goal in
            GoalCompletedView(
                goalName: goal.name,
                onArchive: { try? GoalService(context: context).archive(goal); completedGoal = nil },
                onKeepOpen: { completedGoal = nil }
            )
            .presentationBackground(.clear)
        }
    }

    private func goalCard(_ goal: Goal) -> some View {
        let saved = GoalMath.saved(for: goal)
        let target = goal.targetAmount
        let progress = GoalMath.progress(saved: saved, target: target)
        let monthlyNeeded = GoalMath.monthlyNeeded(saved: saved, target: target, targetDate: goal.targetDate)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                NavigationLink(value: goal) {
                    HStack(spacing: 12) {
                        CategoryIcon(systemName: goal.iconName, size: 40)
                        Text(goal.name).font(.headline).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%").foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
            ProgressBar(fraction: progress)
            HStack {
                Text("\(money.string(saved)) of \(money.string(target))")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
                if let date = goal.targetDate {
                    Text("· by \(date.formatted(.dateTime.month(.abbreviated).year()))")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
            }
            Divider()
            HStack {
                if let monthlyNeeded, monthlyNeeded > 0 {
                    Text("Save \(money.string(monthlyNeeded))/month to stay on track")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                } else {
                    Text("Keep it up").font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button { depositTarget = goal } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(height: 36)
                        .foregroundStyle(Theme.primary)
                        .overlay(Capsule().stroke(Theme.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var newGoalButton: some View {
        Button { showNew = true } label: {
            Label("New goal", systemImage: "plus")
                .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 50)
                .foregroundStyle(Theme.primary)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.primary, lineWidth: 1.5))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "target").font(.system(size: 40)).foregroundStyle(Theme.secondaryText)
            Text("No goals yet").font(.headline).foregroundStyle(Theme.text)
            Text("Set money aside toward something you're saving for.")
                .font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
    }
}
