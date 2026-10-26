//
//  MascotView.swift
//  Pocket Ledger
//
//  The mascot's single call-site API, kept stable across the SwiftUI-placeholder
//  era and the Rive owl:
//    - MascotView(controller:) — the live, animated owl; shows a static Rive
//      pose instead when Reduce Motion is on.
//    - MascotView(mood:)       — a static pose for a given mood (previews).
//    - MascotView(size:)       — the original non-animated placeholder.
//
//  Decorative: hidden from accessibility, never contains text (the app is
//  bilingual; messages live in normal localized Text next to it). This view is
//  Rive-free; the Rive wrappers live in RiveMascotView.swift.
//

import SwiftUI

struct MascotView: View {
    private enum Content {
        case placeholder
        case mood(MascotMood)
        case live(MascotController)
    }

    private let content: Content
    var size: CGFloat
    /// When true (Home only), tapping wakes the sleeping owl or plays `love`,
    /// with a matching haptic. Decorative everywhere else, so default is false.
    var isInteractive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped on wake / love so `.sensoryFeedback` fires the matching haptic.
    @State private var wakeFeedback = 0
    @State private var loveFeedback = 0

    init(size: CGFloat = 60) {
        self.content = .placeholder
        self.size = size
        self.isInteractive = false
    }

    init(mood: MascotMood, size: CGFloat = 60) {
        self.content = .mood(mood)
        self.size = size
        self.isInteractive = false
    }

    init(controller: MascotController, size: CGFloat = 60, isInteractive: Bool = false) {
        self.content = .live(controller)
        self.size = size
        self.isInteractive = isInteractive
    }

    var body: some View {
        poseView
            .frame(width: size, height: size)
            // Keep a tappable target of at least 44pt even for small sizes.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .modifier(MascotTapToPlay(controller: interactiveController,
                                      wakeFeedback: $wakeFeedback,
                                      loveFeedback: $loveFeedback))
            .accessibilityHidden(true)
    }

    /// The controller to drive taps against, or nil when not interactive.
    private var interactiveController: MascotController? {
        guard isInteractive, case .live(let controller) = content else { return nil }
        return controller
    }

    @ViewBuilder private var poseView: some View {
        switch content {
        case .placeholder:
            placeholder
        case .mood(let mood):
            StaticRiveMascotView(mood: mood)
        case .live(let controller):
            // Respect Reduce Motion: no movement, just the static base/sleep pose.
            if reduceMotion {
                StaticRiveMascotView(mood: controller.baseMood, isSleeping: controller.isSleeping)
            } else {
                RiveMascotView(controller: controller)
            }
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Theme.primary.opacity(0.12))
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.42, weight: .regular))
                    .foregroundStyle(Theme.primary.opacity(0.45))
            )
    }
}

/// Adds the tap gesture + haptics when a controller is present; otherwise a
/// no-op so the mascot stays purely decorative. File-scoped so its `body`'s
/// `Content` resolves to `ViewModifier.Content`, not `MascotView.Content`.
private struct MascotTapToPlay: ViewModifier {
    let controller: MascotController?
    @Binding var wakeFeedback: Int
    @Binding var loveFeedback: Int

    func body(content: Content) -> some View {
        if let controller {
            content
                .onTapGesture {
                    switch controller.handleTap() {
                    case .wokeUp: wakeFeedback += 1
                    case .love: loveFeedback += 1
                    case .ignored: break
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: wakeFeedback)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: loveFeedback)
        } else {
            content
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        MascotView(size: 64)
        MascotView(mood: .idle, size: 96)
        MascotView(mood: .overLimit, size: 96)
    }
    .padding()
}
