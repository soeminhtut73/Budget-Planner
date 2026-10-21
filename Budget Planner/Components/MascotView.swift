//
//  MascotView.swift
//  Pocket Ledger
//
//  V1 placeholder for the mascot. It reserves the final footprint but draws
//  no character and plays no animation. The full original character and its
//  states ship in v1.1; keep this view's call sites (size-based init) stable
//  so the character can drop in without changing callers.
//
//  Decorative: hidden from accessibility, never contains text (the app is
//  bilingual; messages live in normal localized Text next to it).
//

import SwiftUI

struct MascotView: View {
    var size: CGFloat = 60

    var body: some View {
        Circle()
            .fill(Theme.primary.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.42, weight: .regular))
                    .foregroundStyle(Theme.primary.opacity(0.45))
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        MascotView()
        MascotView(size: 96)
    }
    .padding()
}
