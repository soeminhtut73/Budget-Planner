//
//  ProgressBar.swift
//  Pocket Ledger
//
//  A simple capsule progress bar. `fraction` may exceed 1 (over budget); the
//  fill is clamped to the track width.
//

import SwiftUI

struct ProgressBar: View {
    let fraction: Double
    var color: Color = Theme.primary
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border.opacity(0.5))
                Capsule()
                    .fill(color)
                    .frame(width: max(6, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBar(fraction: 0.4)
        ProgressBar(fraction: 0.86, color: Theme.warning)
        ProgressBar(fraction: 1.2, color: Theme.expense)
    }
    .padding()
}
