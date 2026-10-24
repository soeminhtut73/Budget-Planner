//
//  GoalCompletedView.swift
//  Pocket Ledger
//
//  Shown when a deposit brings a goal to its target: confetti, a success
//  haptic, and a choice to archive the goal or keep it open. The animated
//  mascot reaction ships in v1.1; here the mascot is the static placeholder.
//

import SwiftUI

struct GoalCompletedView: View {
    let goalName: String
    let onArchive: () -> Void
    let onKeepOpen: () -> Void

    @Environment(MascotController.self) private var mascot
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            card
            ConfettiView().ignoresSafeArea()
        }
        .onAppear {
            appeared = true
            mascot.play(.goalReached)
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private var card: some View {
        VStack(spacing: 16) {
            MascotView(controller: mascot, size: 96)
            Text("Goal reached!")
                .font(.title2.weight(.bold)).foregroundStyle(Theme.text)
            Text("You saved up for \(goalName). ")
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: onArchive) {
                Text("Archive goal")
                    .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 50)
                    .foregroundStyle(.white).background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            Button(action: onKeepOpen) {
                Text("Keep it open")
                    .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 50)
                    .foregroundStyle(Theme.text)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }
}

#Preview {
    GoalCompletedView(goalName: "Trip to Vietnam", onArchive: {}, onKeepOpen: {})
        .environment(MascotController())
}
