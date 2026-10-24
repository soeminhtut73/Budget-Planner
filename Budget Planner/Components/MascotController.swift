//
//  MascotController.swift
//  Pocket Ledger
//
//  One MascotController is created at the app root and injected via
//  `.environment`. Views observe it through `MascotView(controller:)`; view
//  models drive it with `play(_:)` and `setOverLimit(_:)`. The controller holds
//  no Rive dependency — it only models mood state, so it is fully unit-testable.
//

import Observation

@MainActor
@Observable
final class MascotController {
    /// The base mood the mascot rests in: `.overLimit` when a budget is over,
    /// otherwise `.idle`.
    private(set) var baseMood: MascotMood = .idle

    /// The most recent reaction. Replaced on every `play(_:)` with a fresh id,
    /// so repeating the same reaction still fires and a new reaction cancels the
    /// previous one.
    private(set) var lastReaction: MascotReaction?

    init() {}

    /// Plays a one-shot reaction. Base moods (`idle`, `overLimit`) are ignored —
    /// those are set through `setOverLimit(_:)`.
    func play(_ mood: MascotMood) {
        guard mood.isReaction else { return }
        lastReaction = MascotReaction(mood: mood)
    }

    /// Switches the base mood between `.overLimit` and `.idle`.
    func setOverLimit(_ isOver: Bool) {
        baseMood = isOver ? .overLimit : .idle
    }
}
