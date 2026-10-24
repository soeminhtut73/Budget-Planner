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
    /// Category grid starts collapsed; the header toggles it.
    @State private var categoryExpanded = false
    /// Focus for the Note text field. While it's focused we hide the custom
    /// amount keypad so the system keyboard (and the field) are visible.
    @FocusState private var noteFocused: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.money) private var money
    @Environment(MascotController.self) private var mascot

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
            .onAppear { model.mascot = mascot }
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
            // Swipe/scroll the form down to dismiss the note keyboard.
            .scrollDismissesKeyboard(.interactively)

            // Hide the amount keypad while editing the Note, so the system
            // keyboard can show and the note field scrolls into view.
            if !noteFocused {
                NumberPad(allowsDecimal: model.minorUnits > 0) { model.handleKey($0) }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: noteFocused)
        // Tap any empty area (not a chip, row, or the field itself) to dismiss
        // the note keyboard; child controls still receive their own taps.
        .contentShape(Rectangle())
        .onTapGesture { noteFocused = false }
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
            expenseCategoryPicker
            walletPicker
            fieldCard {
                dateRow
                Divider()
                noteRow
            }
            paidFromRow
        }
    }

    /// Category chooser: one horizontal line of tiles by default; the chevron
    /// expands them into a full grid. Picking a category collapses back to one
    /// line. The "New" tile opens the add-category sheet.
    private var expenseCategoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { categoryExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("CATEGORY").font(.caption).foregroundStyle(Theme.secondaryText)
                    Spacer()
                    if let category = model.category {
                        Image(systemName: category.iconName).font(.caption)
                        Text(category.displayName).font(.caption.weight(.semibold)).lineLimit(1)
                    }
                    Image(systemName: categoryExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)

            if categoryExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(model.categoriesForKind) { category in
                        categoryTile(for: category) {
                            model.category = category
                            withAnimation(.snappy) { categoryExpanded = false }
                        }
                    }
                    newCategoryTile
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(model.categoriesForKind) { category in
                                categoryTile(for: category) { model.category = category }
                                    .frame(width: 84)
                                    .id(category.id)
                            }
                            newCategoryTile.frame(width: 84)
                        }
                        .padding(.vertical, 2)
                    }
                    .onAppear { scrollToSelected(proxy) }
                    .onChange(of: model.category?.id) { _, _ in scrollToSelected(proxy) }
                }
            }
        }
    }

    /// Centers the selected category tile in the collapsed one-line row.
    private func scrollToSelected(_ proxy: ScrollViewProxy) {
        guard let id = model.category?.id else { return }
        withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
    }

    private func categoryTile(for category: Category, action: @escaping () -> Void) -> some View {
        categoryTile(icon: category.iconName, label: Text(category.displayName),
                     selected: model.category?.id == category.id, dashed: false, action: action)
    }

    private var newCategoryTile: some View {
        categoryTile(icon: "plus", label: Text("New"), selected: false, dashed: true) {
            showCategoryPicker = true
        }
    }

    /// A small square category tile matching the Add budget page (icon badge +
    /// label); fills its container so grid/row spacing stays even.
    private func categoryTile(icon: String, label: Text, selected: Bool, dashed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                CategoryIcon(systemName: icon, size: 22)
                label
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(dashed ? Theme.secondaryText : Theme.text)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? Theme.primary : Theme.border,
                        style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: dashed ? [4] : [])))
        }
        .buttonStyle(.plain)
    }

    /// Inline wallet chooser: a horizontal row of chips (icon + name), tap to
    /// select. Avoids opening a separate wallet screen.
    private var walletPicker: some View {
        chipRow(title: "WALLET") {
            ForEach(model.wallets) { wallet in
                Chip(isSelected: model.wallet?.id == wallet.id) {
                    model.wallet = wallet
                } label: {
                    Label { Text(wallet.name) } icon: { Image(systemName: wallet.iconName) }
                }
            }
        }
    }

    /// A titled, horizontally scrolling row of chips.
    private func chipRow<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
                    .padding(.vertical, 2)
            }
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
                .focused($noteFocused)
                .submitLabel(.done)
                .onSubmit { noteFocused = false }
        }
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
        .environment(MascotController())
}
