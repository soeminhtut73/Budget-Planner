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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(size: CGFloat = 60) {
        self.content = .placeholder
        self.size = size
    }

    init(mood: MascotMood, size: CGFloat = 60) {
        self.content = .mood(mood)
        self.size = size
    }

    init(controller: MascotController, size: CGFloat = 60) {
        self.content = .live(controller)
        self.size = size
    }

    var body: some View {
        poseView
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var poseView: some View {
        switch content {
        case .placeholder:
            placeholder
        case .mood(let mood):
            StaticRiveMascotView(mood: mood)
        case .live(let controller):
            // Respect Reduce Motion: no movement, just the static base pose.
            if reduceMotion {
                StaticRiveMascotView(mood: controller.baseMood)
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

#Preview {
    HStack(spacing: 16) {
        MascotView(size: 64)
        MascotView(mood: .idle, size: 96)
        MascotView(mood: .overLimit, size: 96)
    }
    .padding()
}
