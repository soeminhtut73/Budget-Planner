//
//  ConfettiView.swift
//  Pocket Ledger
//
//  A short confetti burst for goal completion. Respects Reduce Motion (renders
//  nothing when it's on). Decorative and non-interactive.
//

import SwiftUI

struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    private let pieces = (0..<44).map { _ in ConfettiPiece() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 7, height: 11)
                        .rotationEffect(.degrees(animate ? piece.endRotation : piece.startRotation))
                        .position(
                            x: piece.x * geo.size.width,
                            y: animate ? geo.size.height + 24 : -24
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(reduceMotion ? nil : .easeIn(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
            .onAppear { if !reduceMotion { animate = true } }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x = CGFloat.random(in: 0...1)
    let color = [Theme.primary, Theme.warning, Theme.expense, Color.pink, Color.blue].randomElement() ?? Theme.primary
    let duration = Double.random(in: 1.2...2.2)
    let delay = Double.random(in: 0...0.4)
    let startRotation = Double.random(in: 0...360)
    let endRotation = Double.random(in: 180...720)
}

#Preview {
    ConfettiView().frame(height: 400)
}
