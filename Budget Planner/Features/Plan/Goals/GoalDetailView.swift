//
//  GoalDetailView.swift
//  Pocket Ledger
//
//  One goal: progress, add/withdraw, the entry history, and edit/archive.
//

import SwiftUI
import SwiftData

struct GoalDetailView: View {
    let goal: Goal

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showEdit = false
    @State private var sheetMode: AddToGoalSheet.Mode?
    @State private var completed = false

    private var currencyCode: String { settingsList.first?.mainCurrency ?? "USD" }
    private var saved: Decimal { GoalMath.saved(for: goal) }
    private var entries: [GoalEntry] {
        (goal.entries ?? []).filter { $0.deletedAt == nil }.sorted { $0.occurredAt > $1.occurredAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                actionButtons
                entriesCard
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button { showEdit = true } label: { Label("Edit goal", systemImage: "pencil") }
                    Button { archive() } label: { Label("Archive goal", systemImage: "archivebox") }
                    Button(role: .destructive) { delete() } label: { Label("Delete goal", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) { NewEditGoalView(editingGoal: goal) }
        .sheet(item: $sheetMode) { mode in
            AddToGoalSheet(goal: goal, mode: mode, onCompleted: { completed = true })
        }
        .fullScreenCover(isPresented: $completed) {
            GoalCompletedView(
                goalName: goal.name,
                onArchive: { try? GoalService(context: context).archive(goal); completed = false; dismiss() },
                onKeepOpen: { completed = false }
            )
            .presentationBackground(.clear)
        }
    }

    private var summaryCard: some View {
        let target = goal.targetAmount
        let progress = GoalMath.progress(saved: saved, target: target)
        let monthlyNeeded = GoalMath.monthlyNeeded(saved: saved, target: target, targetDate: goal.targetDate)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(saved.formatted(.currency(code: currencyCode)))
                    .font(.largeTitle.weight(.bold)).foregroundStyle(Theme.text)
                Text("of \(target.formatted(.currency(code: currencyCode)))")
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%").foregroundStyle(Theme.secondaryText)
            }
            ProgressBar(fraction: progress)
            HStack {
                if let date = goal.targetDate {
                    Label(date.formatted(.dateTime.month(.abbreviated).year()), systemImage: "calendar")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if let monthlyNeeded, monthlyNeeded > 0 {
                    Text("\(monthlyNeeded.formatted(.currency(code: currencyCode)))/month")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                } else if GoalMath.isComplete(saved: saved, target: target) {
                    Text("Reached 🎉").font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { sheetMode = .deposit } label: {
                Label("Add", systemImage: "plus")
                    .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 48)
                    .foregroundStyle(.white).background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            Button { sheetMode = .withdraw } label: {
                Label("Withdraw", systemImage: "arrow.up")
                    .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 48)
                    .foregroundStyle(Theme.text)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            if entries.isEmpty {
                Text("No entries yet").foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(entry)
                    if index < entries.count - 1 { Divider() }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func entryRow(_ entry: GoalEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entryLabel(entry.kind)).foregroundStyle(Theme.text)
                Text(entry.occurredAt, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            AmountText(amount: entry.amount,
                       style: entry.kind == .deposit ? .income : .expense,
                       currencyCode: currencyCode)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }

    private func entryLabel(_ kind: GoalEntryKind) -> LocalizedStringKey {
        switch kind {
        case .deposit: return "Added"
        case .withdraw: return "Withdrew"
        case .spend: return "Spent from goal"
        }
    }

    private func archive() {
        try? GoalService(context: context).archive(goal)
        dismiss()
    }

    private func delete() {
        try? GoalService(context: context).delete(goal)
        dismiss()
    }
}

extension AddToGoalSheet.Mode: Identifiable {
    public var id: Int { self == .deposit ? 0 : 1 }
}
