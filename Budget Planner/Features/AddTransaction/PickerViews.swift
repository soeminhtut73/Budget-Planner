//
//  PickerViews.swift
//  Pocket Ledger
//
//  Selection sheets for the Add transaction screen: pick a category (with an
//  option to add a custom one) or a wallet.
//

import SwiftUI

struct CategoryPickerView: View {
    let categories: [Category]
    @Binding var selection: Category?
    var onAddNew: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingNew = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        selection = category
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            CategoryIcon(category: category, size: 32)
                            CategoryLabel(category: category)
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if selection?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }
                Button {
                    showingNew = true
                } label: {
                    Label("New category", systemImage: "plus")
                        .foregroundStyle(Theme.primary)
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("New category", isPresented: $showingNew) {
                TextField("Name", text: $newName)
                Button("Add") {
                    onAddNew(newName)
                    newName = ""
                    dismiss()
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
        }
    }
}

struct WalletPickerView: View {
    let wallets: [Wallet]
    @Binding var selection: Wallet?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(wallets) { wallet in
                Button {
                    selection = wallet
                    dismiss()
                } label: {
                    HStack {
                        Text(wallet.name).foregroundStyle(Theme.text)
                        Spacer()
                        if selection?.id == wallet.id {
                            Image(systemName: "checkmark").foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
