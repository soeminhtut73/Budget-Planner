//
//  PreviewData.swift
//  Pocket Ledger
//
//  DEBUG-only in-memory containers for SwiftUI previews.
//

#if DEBUG
import SwiftData

enum PreviewData {
    /// An in-memory container seeded with defaults and a little sample data.
    @MainActor
    static func container(sampleCount: Int = 60) -> ModelContainer {
        guard let container = try? AppSchema.makeContainer(inMemory: true) else {
            fatalError("Failed to build preview container")
        }
        let context = container.mainContext
        try? SeedService.seedIfNeeded(context: context)
        if sampleCount > 0 {
            try? SampleData.generate(context: context, count: sampleCount)
        }
        return container
    }
}
#endif
