//
//  MainTabView.swift
//  Pocket Ledger
//
//  The app's 4-tab shell (Home · Activity · Plan · Reports) and the floating
//  "+" that opens Add transaction. The Loans tab is V2.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    enum Tab: Hashable { case home, activity, plan, reports }

    @Environment(\.modelContext) private var context
    @State private var selectedTab: Tab = .home
    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                HomeView(onShowActivity: { _ in selectedTab = .activity })
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)
                ActivityPlaceholderView()
                    .tabItem { Label("Activity", systemImage: "list.bullet") }
                    .tag(Tab.activity)
                PlanPlaceholderView()
                    .tabItem { Label("Plan", systemImage: "chart.pie.fill") }
                    .tag(Tab.plan)
                ReportsPlaceholderView()
                    .tabItem { Label("Reports", systemImage: "chart.bar.fill") }
                    .tag(Tab.reports)
            }
            .tint(Theme.primary)

            if selectedTab == .home || selectedTab == .activity {
                addButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 72)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView(context: context)
        }
    }

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.primary, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel("Add transaction")
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewData.container())
}
