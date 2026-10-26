//
//  AddCategoryView.swift
//  Pocket Ledger
//
//  Create a custom category: pick expense/income, type a name, and choose an
//  icon from the SF Symbol palette. V1 uses SF Symbols only (no emoji / custom
//  art), per the design rules.
//

import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: CategoryKind
    @State private var name: String = ""
    @State private var iconName: String = CategoryIconOptions.default

    /// Called with the created category before dismissing. Callers that select
    /// the new category right away (e.g. Add transaction) use this; Settings
    /// leaves it nil and relies on its own @Query to refresh.
    private let onCreated: ((Category) -> Void)?

    init(initialKind: CategoryKind = .expense, onCreated: ((Category) -> Void)? = nil) {
        _kind = State(initialValue: initialKind)
        self.onCreated = onCreated
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    preview
                    kindPicker
                    nameField
                    iconPicker
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 12) {
            CategoryIcon(systemName: iconName, color: kind == .income ? Theme.income : Theme.primary, size: 48)
            Text(trimmedName.isEmpty ? String(localized: "Category name") : trimmedName)
                .font(.headline)
                .foregroundStyle(trimmedName.isEmpty ? Theme.secondaryText : Theme.text)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var kindPicker: some View {
        Picker("Type", selection: $kind) {
            Text("Expense").tag(CategoryKind.expense)
            Text("Income").tag(CategoryKind.income)
        }
        .pickerStyle(.segmented)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NAME").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            TextField("e.g. Coffee", text: $name)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ICON").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CategoryIconOptions.all, id: \.self) { symbol in
                    let selected = symbol == iconName
                    Button { iconName = symbol } label: {
                        CategoryIcon(systemName: symbol,
                                     color: kind == .income ? Theme.income : Theme.primary,
                                     size: 44)
                            .padding(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selected ? Theme.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            let category = try SwiftDataCategoryRepository(context: context)
                .createCustom(kind: kind, name: trimmedName, iconName: iconName)
            onCreated?(category)
            dismiss()
        } catch {
            assertionFailure("Create category failed: \(error)")
        }
    }
}

#Preview {
    AddCategoryView()
        .modelContainer(PreviewData.container())
}
