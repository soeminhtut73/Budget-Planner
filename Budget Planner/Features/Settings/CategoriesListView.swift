//
//  CategoriesListView.swift
//  Pocket Ledger
//
//  Settings → Categories: manage expense and income categories. Default
//  categories are protected (no delete). Custom categories can be deleted;
//  deleting one also removes its budget, while past records keep their name.
//

import SwiftUI
import SwiftData

struct CategoriesListView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Category> { $0.deletedAt == nil && $0.isArchived == false },
           sort: \Category.sortOrder)
    private var categories: [Category]

    @State private var showAdd = false
    @State private var addKind: CategoryKind = .expense
    @State private var pendingDelete: Category?

    private var expense: [Category] { categories.filter { $0.kind == .expense } }
    private var income: [Category] { categories.filter { $0.kind == .income } }

    var body: some View {
        List {
            section(title: "Expense", items: expense, kind: .expense)
            section(title: "Income", items: income, kind: .income)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { addKind = .expense; showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add category")
            }
        }
        .sheet(isPresented: $showAdd) { AddCategoryView(initialKind: addKind) }
        .confirmationDialog(
            "Delete this category?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete category", role: .destructive) {
                if let category = pendingDelete {
                    try? SwiftDataCategoryRepository(context: context).deleteCustom(category)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let category = pendingDelete, category.budget != nil {
                Text("This also removes its budget. Past records keep their name.")
            } else {
                Text("Past records keep their name.")
            }
        }
    }

    @ViewBuilder
    private func section(title: LocalizedStringKey, items: [Category], kind: CategoryKind) -> some View {
        Section {
            ForEach(items) { category in
                row(category)
                    .swipeActions(edge: .trailing) {
                        if !category.isDefault {
                            Button(role: .destructive) { pendingDelete = category } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
            Button { addKind = kind; showAdd = true } label: {
                Label("Add category", systemImage: "plus.circle.fill")
                    .foregroundStyle(Theme.primary)
            }
        } header: {
            Text(title)
        }
    }

    private func row(_ category: Category) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(systemName: category.iconName,
                         color: category.kind == .income ? Theme.income : Theme.primary,
                         size: 36)
            Text(category.displayName).foregroundStyle(Theme.text)
            Spacer()
            if category.isDefault {
                Text("Default").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesListView()
            .modelContainer(PreviewData.container())
    }
}
