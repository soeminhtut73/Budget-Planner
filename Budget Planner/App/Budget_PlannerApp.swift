//
//  Budget_PlannerApp.swift
//  Pocket Ledger
//

import SwiftUI
import SwiftData

@main
struct Budget_PlannerApp: App {
    let sharedModelContainer: ModelContainer = {
        do {
            return try AppSchema.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let context = sharedModelContainer.mainContext
        do {
            try SeedService.seedIfNeeded(context: context)
            try RecurringService.postDueRules(context: context)
        } catch {
            assertionFailure("Launch setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
