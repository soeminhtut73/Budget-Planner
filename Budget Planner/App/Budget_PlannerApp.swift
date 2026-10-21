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
        do {
            try SeedService.seedIfNeeded(context: sharedModelContainer.mainContext)
        } catch {
            assertionFailure("First-launch seeding failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
