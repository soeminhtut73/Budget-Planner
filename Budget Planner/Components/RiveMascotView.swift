//
//  RiveMascotView.swift
//  Pocket Ledger
//
//  The RiveRuntime-backed owl. This is the only file that imports Rive; all
//  mood logic lives in MascotController and the mood→trigger mapping in
//  MascotRiveInputs, so the rest of the app (and the tests) stay Rive-free.
//
//  The Rive state machine ("Main") owns the visual return to idle/sad after a
//  reaction; we only fire triggers and set the overLimit boolean.
//

import SwiftUI
import RiveRuntime

/// Wraps a RiveViewModel for the owl artboard and exposes mood-driven inputs.
@MainActor
final class RiveOwlDriver {
    let viewModel: RiveViewModel

    /// Tracks the last reaction we fired so a reaction plays at most once per
    /// driver instance (whether it arrived via onAppear or onChange).
    private var lastPlayedReactionID: UUID?

    init(autoPlay: Bool = true) {
        viewModel = RiveViewModel(
            fileName: MascotRiveInputs.fileName,
            stateMachineName: MascotRiveInputs.stateMachine,
            fit: .contain,
            autoPlay: autoPlay,
            artboardName: MascotRiveInputs.artboard
        )
    }

    /// Fires the matching state-machine trigger. Base moods do nothing.
    func play(_ mood: MascotMood) {
        guard let trigger = MascotRiveInputs.trigger(for: mood) else { return }
        viewModel.triggerInput(trigger)
    }

    /// Plays a reaction only if it hasn't been played yet by this driver.
    func playIfNew(_ reaction: MascotReaction?) {
        guard let reaction, reaction.id != lastPlayedReactionID else { return }
        lastPlayedReactionID = reaction.id
        play(reaction.mood)
    }

    /// Sets the overLimit boolean (sad base pose when true).
    func setOverLimit(_ isOver: Bool) {
        viewModel.setInput(MascotRiveInputs.overLimitBool, value: isOver)
    }
}

/// The animated mascot. Keeps its driver in @State so it survives re-renders.
struct RiveMascotView: View {
    let controller: MascotController
    @State private var driver = RiveOwlDriver()

    var body: some View {
        driver.viewModel.view()
            .onAppear {
                driver.setOverLimit(controller.baseMood == .overLimit)
                driver.playIfNew(controller.lastReaction)
            }
            .onChange(of: controller.baseMood) { _, mood in
                driver.setOverLimit(mood == .overLimit)
            }
            .onChange(of: controller.lastReaction) { _, reaction in
                driver.playIfNew(reaction)
            }
    }
}

/// A static (non-animating) owl pose for Reduce Motion and for `MascotView(mood:)`.
/// The state machine is loaded but not auto-played; only the base pose shows.
struct StaticRiveMascotView: View {
    let mood: MascotMood
    @State private var driver = RiveOwlDriver(autoPlay: false)

    var body: some View {
        driver.viewModel.view()
            .onAppear { driver.setOverLimit(mood == .overLimit) }
            .onChange(of: mood) { _, newMood in
                driver.setOverLimit(newMood == .overLimit)
            }
    }
}
