//
//  AddTransactionView.swift
//  Pocket Ledger
//
//  The Add / Edit transaction sheet. Expense | Income modes, a custom amount
//  keypad, category/wallet/date/note fields, an income balance preview, and
//  the saved-confirmation overlay.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @State private var model: AddTransactionViewModel
    @State private var savedSummary: TransactionService.SavedSummary?
    @State private var showCategoryPicker = false
    @State private var showWalletPicker = false
    @State private var showGoalPicker = false
    @State private var showDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.money) private var money

    init(context: ModelContext, editing: Transaction? = nil, presetCategoryID: UUID? = nil) {
        _model = State(initialValue: AddTransactionViewModel(context: context, editing: editing, presetCategoryID: presetCategoryID))
    }

    private var dayBinding: Binding<Date> {
        Binding(get: { model.occurredAt }, set: { model.setDay($0) })
    }

    private var kindBinding: Binding<TransactionKind> {
        Binding(get: { model.kind }, set: { model.selectKind($0) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
                if let summary = savedSummary {
                    SavedConfirmationView(
                        summary: summary,
                        onAddAnother: {
                            savedSummary = nil
                            model.resetForAnother()
                        },
                        onDismiss: { dismiss() }
                    )
                }
            }
            .navigationTitle(model.isEditing ? "Edit transaction" : "New transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!model.canSave)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(
                    categories: model.categoriesForKind,
                    selection: $model.category,
                    onAddNew: { model.addCustomCategory(named: $0) }
                )
            }
            .sheet(isPresented: $showWalletPicker) {
                WalletPickerView(wallets: model.wallets, selection: $model.wallet)
            }
            .sheet(isPresented: $showGoalPicker) {
                GoalPickerView(goals: model.goals, selection: $model.paidFromGoal)
            }
            .confirmationDialog("Delete this transaction?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteTransaction() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 16) {
            SegmentedToggle(selection: kindBinding, options: [
                (.expense, "Expense"), (.income, "Income"),
            ])
            .padding(.horizontal)
            .padding(.top, 8)

            amountDisplay

            ScrollView {
                VStack(spacing: 16) {
                    if model.kind == .expense {
                        expenseFields
                    } else {
                        incomeFields
                    }
                    if model.isEditing {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete transaction", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
            }

            NumberPad(allowsDecimal: model.minorUnits > 0) { model.handleKey($0) }
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    private var amountDisplay: some View {
        VStack(spacing: 2) {
            Text("Amount · \(model.currencyCode)")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            AmountText(
                amount: model.amount,
                style: model.kind == .income ? .income : .neutral,
                tint: model.amount == 0 ? Theme.secondaryText : nil
            )
            .font(.system(size: 44, weight: .bold))
            .contentTransition(.numericText())
            .animation(.snappy, value: model.amount)
        }
    }

    // MARK: Expense

    private var expenseFields: some View {
        VStack(spacing: 16) {
            fieldCard {
                pickerRow(title: "Category", value: categoryValueText) { showCategoryPicker = true }
                Divider()
                pickerRow(title: "Wallet", value: model.wallet?.name ?? "—") { showWalletPicker = true }
                Divider()
                dateRow
                Divider()
                noteRow
            }
            paidFromRow
        }
    }

    private var paidFromRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Paid from").foregroundStyle(Theme.secondaryText)
                Spacer()
                Button { model.paidFromGoal = nil } label: {
                    paidFromPill(text: Text("Wallet"), selected: model.paidFromGoal == nil)
                }
                .buttonStyle(.plain)
                Button {
                    if !model.goals.isEmpty { showGoalPicker = true }
                } label: {
                    paidFromPill(text: Text(model.paidFromGoal?.name ?? String(localized: "Goal")),
                                 selected: model.paidFromGoal != nil)
                }
                .buttonStyle(.plain)
                .disabled(model.goals.isEmpty)
            }
            if model.goals.isEmpty {
                Text("Add a savings goal to pay from it").font(.caption2).foregroundStyle(Theme.secondaryText)
            } else if model.paidFromGoal != nil {
                Text("Reduces Total and the goal; excluded from budgets")
                    .font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.bottom, 4)
    }

    private func paidFromPill(text: Text, selected: Bool) -> some View {
        text
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).frame(height: 32)
            .foregroundStyle(selected ? Color.white : Theme.secondaryText)
            .background(selected ? Theme.primary : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Theme.border))
    }

    // MARK: Income

    private var incomeFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SOURCE")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                FlowLayout(spacing: 8) {
                    ForEach(model.incomeCategories) { category in
                        Chip(isSelected: model.category?.id == category.id) {
                            model.category = category
                        } label: {
                            CategoryLabel(category: category)
                        }
                    }
                    Chip("+ New", isSelected: false) { showCategoryPicker = true }
                }
            }

            fieldCard {
                pickerRow(title: "Into wallet", value: model.wallet?.name ?? "—") { showWalletPicker = true }
                Divider()
                dateRow
                Divider()
                Toggle("Repeat monthly", isOn: $model.repeatMonthly)
                    .tint(Theme.primary)
                    .padding(.vertical, 4)
                Divider()
                noteRow
            }

            if let preview = model.incomePreview {
                previewCard(preview)
            }
        }
    }

    private func previewCard(_ preview: AddTransactionViewModel.BalancePreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AFTER SAVING").font(.caption).foregroundStyle(Theme.secondaryText)
            previewRow(label: model.wallet?.name ?? "Wallet", before: preview.walletBefore, after: preview.walletAfter)
            previewRow(label: "Total balance", before: preview.totalBefore, after: preview.totalAfter)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.border.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private func previewRow(label: String, before: Decimal, after: Decimal) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(money.string(before))
                .foregroundStyle(Theme.secondaryText)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(Theme.secondaryText)
            Text(money.string(after))
                .fontWeight(.semibold)
                .foregroundStyle(Theme.text)
        }
        .font(.subheadline)
    }

    // MARK: Shared rows

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func pickerRow(title: LocalizedStringKey, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(value).fontWeight(.semibold).foregroundStyle(Theme.text)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private var dateRow: some View {
        HStack {
            Text("Date").foregroundStyle(Theme.secondaryText)
            Spacer()
            DatePicker("", selection: dayBinding, displayedComponents: .date)
                .labelsHidden()
        }
    }

    private var noteRow: some View {
        HStack {
            Text("Note").foregroundStyle(Theme.secondaryText)
            Spacer()
            TextField("Optional", text: $model.note)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.text)
        }
    }

    private var categoryValueText: String {
        model.category?.displayName ?? "—"
    }

    // MARK: Actions

    private func save() {
        do {
            if let summary = try model.save() {
                if model.isEditing {
                    dismiss()
                } else {
                    savedSummary = summary
                }
            }
        } catch {
            assertionFailure("Save failed: \(error)")
        }
    }

    private func deleteTransaction() {
        do {
            try model.delete()
            dismiss()
        } catch {
            assertionFailure("Delete failed: \(error)")
        }
    }
}

#Preview {
    AddTransactionView(context: PreviewData.container(sampleCount: 20).mainContext)
}
