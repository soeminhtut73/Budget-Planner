//
//  ActivityView.swift
//  Pocket Ledger
//
//  The Activity list: month selector, search, filter chips, records grouped by
//  local day with day net totals, swipe to edit/delete, tap to edit.
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var context
    @State private var model: ActivityViewModel
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?
    @Binding var requestedWalletID: UUID?

    init(context: ModelContext, requestedWalletID: Binding<UUID?> = .constant(nil), initialCategoryID: UUID? = nil) {
        _model = State(initialValue: ActivityViewModel(context: context, initialWalletID: requestedWalletID.wrappedValue, initialCategoryID: initialCategoryID))
        _requestedWalletID = requestedWalletID
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            searchField
            filterChips
            list
        }
        .padding(.top, 8)
        .background(Theme.background)
        .sheet(item: $editing, onDismiss: { model.reload() }) { tx in
            AddTransactionView(context: context, editing: tx)
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tx = pendingDelete { model.delete(tx) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .onChange(of: requestedWalletID) { _, newValue in
            if let id = newValue {
                model.setWalletFilter(id)
                requestedWalletID = nil
            }
        }
        .onAppear { model.reload() }
    }

    // MARK: Header + month menu

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Activity").font(.largeTitle.weight(.bold)).foregroundStyle(Theme.text)
            Spacer()
            Menu {
                ForEach(recentMonths, id: \.self) { month in
                    Button(month.formatted(.dateTime.month(.wide).year())) {
                        model.filters.month = month
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.filters.month, format: .dateTime.month(.wide).year())
                    Image(systemName: "chevron.down").font(.caption)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal)
    }

    private var recentMonths: [Date] {
        let cal = Calendar.current
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return (0..<12).compactMap { cal.date(byAdding: .month, value: -$0, to: thisMonth) }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
            TextField("Search transactions", text: $model.filters.searchText)
                .textInputAutocapitalization(.never)
            if !model.filters.searchText.isEmpty {
                Button { model.filters.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip("All", isSelected: model.filters.kind == .all) { model.filters.kind = .all }
                Chip("Income", isSelected: model.filters.kind == .income) { model.filters.kind = .income }
                Chip("Expense", isSelected: model.filters.kind == .expense) { model.filters.kind = .expense }

                Menu {
                    Button("All wallets") { model.filters.walletID = nil }
                    ForEach(model.wallets) { wallet in
                        Button(wallet.name) { model.filters.walletID = wallet.id }
                    }
                } label: {
                    walletChipLabel
                }

                if let category = model.pinnedCategory {
                    Chip(isSelected: true, action: { model.filters.categoryID = nil }) {
                        HStack(spacing: 4) {
                            CategoryLabel(category: category)
                            Image(systemName: "xmark").font(.caption2)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var walletChipLabel: some View {
        let name = model.wallets.first { $0.id == model.filters.walletID }?.name
        return HStack(spacing: 4) {
            Text(name ?? String(localized: "Wallet"))
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(model.filters.walletID != nil ? Color.white : Theme.text)
        .padding(.horizontal, 14).frame(height: 36)
        .background(model.filters.walletID != nil ? Theme.primary : Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(model.filters.walletID != nil ? Color.clear : Theme.border, lineWidth: 1))
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        if model.sections.isEmpty {
            emptyState
        } else {
            List {
                ForEach(model.sections) { section in
                    Section {
                        ForEach(section.items) { tx in
                            TransactionRow(transaction: tx)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = tx }
                                .onAppear { model.onRowAppear(tx) }
                                .listRowBackground(Theme.background)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDelete = tx } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button { editing = tx } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(Theme.primary)
                                }
                        }
                    } header: {
                        dayHeader(section)
                    }
                }
                if model.isLoading && !model.reachedEnd {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Theme.background)
                }
            }
            .listStyle(.plain)
        }
    }

    private func dayHeader(_ section: ActivityDaySection) -> some View {
        HStack {
            Text(dayLabel(section.date))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            AmountText(
                amount: section.net,
                style: section.net < 0 ? .expense : .income
            )
            .font(.footnote.weight(.semibold))
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let dayMonth = date.formatted(.dateTime.day().month(.abbreviated))
        if cal.isDateInToday(date) { return "\(String(localized: "Today")) · \(dayMonth)" }
        if cal.isDateInYesterday(date) { return "\(String(localized: "Yesterday")) · \(dayMonth)" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(Theme.secondaryText)
            Text("No records here").font(.headline).foregroundStyle(Theme.text)
            Text("Tap + to add your first one").font(.subheadline).foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("USD") {
    ActivityView(context: PreviewData.container().mainContext, requestedWalletID: .constant(nil))
        .environment(\.money, MoneyFormatter(currencyCode: "USD"))
}

#Preview("MMK") {
    ActivityView(context: PreviewData.container().mainContext, requestedWalletID: .constant(nil))
        .environment(\.money, MoneyFormatter(currencyCode: "MMK"))
}
