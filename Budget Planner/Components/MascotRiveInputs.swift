//
//  MascotRiveInputs.swift
//  Pocket Ledger
//
//  Single source of truth for the owl Rive file's names, plus the pure
//  mood-to-trigger mapping. Deliberately free of RiveRuntime so the mapping can
//  be unit-tested without the Rive dependency. If the .riv contract changes,
//  this is the only file to edit.
//
//  Rive contract: artboard "Owl", state machine "Main", triggers cashIn,
//  cashOut, saving, goalReached, love, booleans overLimit and sleeping.
//  wakeUp plays automatically when `sleeping` goes false.
//

enum MascotRiveInputs {
    static let fileName = "owl"
    static let stateMachine = "Main"
    static let artboard = "Owl"
    static let overLimitBool = "overLimit"
    static let sleepingBool = "sleeping"

    /// The state-machine trigger for a reaction mood, or nil for base moods
    /// (idle / overLimit are driven by booleans, not a trigger).
    static func trigger(for mood: MascotMood) -> String? {
        switch mood {
        case .cashIn: return "cashIn"
        case .cashOut: return "cashOut"
        case .saving: return "saving"
        case .goalReached: return "goalReached"
        case .love: return "love"
        case .idle, .overLimit: return nil
        }
    }
}
