//
//  MascotController.swift
//  Pocket Ledger
//
//  One MascotController is created at the app root and injected via
//  `.environment`. Views observe it through `MascotView(controller:)`; view
//  models drive it with `play(_:)` and `setOverLimit(_:)`. The controller holds
//  no Rive dependency — it only models mood state, so it is fully unit-testable.
//
//  Night behavior: the owl sleeps 21:00–06:00 local time. A tap wakes it; a tap
//  while awake plays `love`; at night it dozes back to sleep after 60s of no
//  activity. The schedule is driven by an injected clock so it can be tested
//  with a fake time. Timers live in the view (which calls `refresh()`); the
//  controller only decides state from the clock, keeping it UIKit/Rive-free.
//

import Foundation
import Observation

@MainActor
@Observable
final class MascotController {
    /// What a tap did, so the view can play the matching haptic.
    enum TapOutcome: Equatable {
        case ignored   // during the wake-up window; no feedback
        case wokeUp    // light haptic
        case love      // soft haptic
    }

    /// The base mood the mascot rests in: `.overLimit` when a budget is over,
    /// otherwise `.idle`.
    private(set) var baseMood: MascotMood = .idle

    /// The most recent reaction. Replaced on every `play(_:)` with a fresh id,
    /// so repeating the same reaction still fires and a new reaction cancels the
    /// previous one.
    private(set) var lastReaction: MascotReaction?

    /// Whether the owl is currently asleep (night, not woken).
    private(set) var isSleeping: Bool = false

    // MARK: Schedule configuration

    /// Night runs from `nightStartHour` (inclusive) to `dayStartHour` (exclusive).
    private let nightStartHour = 21
    private let dayStartHour = 6
    /// Taps are ignored for this long after a wake, so a double-tap doesn't skip
    /// straight into `love` (matches the Rive wakeUp timeline length).
    private let wakeUpDuration: TimeInterval = 1.6
    /// At night, an awake owl dozes off after this much inactivity.
    private let dozeDelay: TimeInterval = 60

    private let now: () -> Date
    private var calendar: Calendar

    private var wasNight: Bool?
    private var wakeStartedAt: Date?
    private var lastActivityAt: Date?

    init(now: @escaping () -> Date = { Date() }, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    // MARK: Reactions / base mood

    /// Plays a one-shot reaction. Base moods (`idle`, `overLimit`) are ignored —
    /// those are set through `setOverLimit(_:)`. A reaction never changes
    /// `isSleeping` (a reaction while asleep returns to sleep afterwards) but it
    /// does count as activity, resetting the night doze timer.
    func play(_ mood: MascotMood) {
        guard mood.isReaction else { return }
        lastReaction = MascotReaction(mood: mood)
        lastActivityAt = now()
    }

    /// Switches the base mood between `.overLimit` and `.idle`.
    func setOverLimit(_ isOver: Bool) {
        baseMood = isOver ? .overLimit : .idle
    }

    // MARK: Sleep schedule

    /// True when the given date is within the night window in the local calendar.
    private func isNight(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= nightStartHour || hour < dayStartHour
    }

    /// Re-evaluates sleep state against the clock. Call on scene-active, on a
    /// periodic tick while open, and when Home appears.
    func refresh() {
        let date = now()
        let night = isNight(date)
        defer { wasNight = night }

        if night {
            if wasNight != true {
                // Entering night (or first evaluation at night): sleep by
                // default, even if a budget is over the limit.
                isSleeping = true
                wakeStartedAt = nil
                lastActivityAt = nil
            } else if !isSleeping, let last = lastActivityAt,
                      date.timeIntervalSince(last) >= dozeDelay {
                // Awake at night with no recent activity → doze off.
                isSleeping = true
            }
        } else {
            if wasNight == true {
                // Crossed into day (e.g. 06:00): wake automatically.
                wake()
            } else {
                isSleeping = false
            }
        }
    }

    /// Wakes the owl and starts the wake-up window.
    private func wake() {
        isSleeping = false
        let date = now()
        wakeStartedAt = date
        lastActivityAt = date
    }

    // MARK: Tap

    /// Handles a tap on the Home mascot. Returns what happened so the view can
    /// play the right haptic.
    @discardableResult
    func handleTap() -> TapOutcome {
        let date = now()
        // Ignore taps during the wake-up animation.
        if let wokeAt = wakeStartedAt, date.timeIntervalSince(wokeAt) < wakeUpDuration {
            return .ignored
        }
        if isSleeping {
            wake()
            return .wokeUp
        } else {
            lastActivityAt = date
            play(.love)
            return .love
        }
    }
}
