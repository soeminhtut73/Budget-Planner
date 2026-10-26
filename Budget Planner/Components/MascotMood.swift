//
//  MascotMood.swift
//  Pocket Ledger
//
//  The mascot's moods. `idle` and `overLimit` are base moods the mascot rests
//  in; the others are one-shot reactions that play once and then return to the
//  current base mood (the Rive state machine handles the visual return).
//

import Foundation

enum MascotMood: Equatable, Sendable {
    case idle
    case cashIn
    case cashOut
    case saving
    case goalReached
    case love
    case overLimit

    /// One-shot reactions (cashIn, cashOut, saving, goalReached, love).
    var isReaction: Bool {
        switch self {
        case .cashIn, .cashOut, .saving, .goalReached, .love: return true
        case .idle, .overLimit: return false
        }
    }

    /// Base moods the mascot rests in (idle, overLimit).
    var isBase: Bool { !isReaction }
}

/// A single reaction event. The `id` makes each `play` distinct, so the same
/// reaction fired twice in a row still registers as a change.
struct MascotReaction: Equatable {
    let mood: MascotMood
    let id = UUID()
}
