//
//  MascotTests.swift
//  Budget PlannerTests
//
//  The mascot's mood logic: the controller's reactions and base mood, the
//  mood→Rive-trigger mapping, and the budget over-limit helper that drives the
//  sad base mood. Kept free of RiveRuntime — only the pure logic is tested.
//

import Testing
import Foundation
@testable import Budget_Planner

@MainActor
@Suite("Mascot")
struct MascotTests {

    @Test("play sets lastReaction with the right mood")
    func playSetsReaction() {
        let controller = MascotController()
        #expect(controller.lastReaction == nil)
        controller.play(.cashIn)
        #expect(controller.lastReaction?.mood == .cashIn)
    }

    @Test("the same reaction twice produces two different reaction values")
    func sameReactionTwiceFires() {
        let controller = MascotController()
        controller.play(.cashIn)
        let first = controller.lastReaction
        controller.play(.cashIn)
        let second = controller.lastReaction
        #expect(first != second)            // different ids → re-fires
        #expect(first?.mood == second?.mood)
    }

    @Test("a new reaction cancels (replaces) the previous one")
    func newReactionReplaces() {
        let controller = MascotController()
        controller.play(.cashIn)
        controller.play(.cashOut)
        #expect(controller.lastReaction?.mood == .cashOut)
    }

    @Test("reactions return to base: play does not change the base mood")
    func reactionKeepsBaseMood() {
        let controller = MascotController()
        #expect(controller.baseMood == .idle)
        controller.play(.cashIn)
        #expect(controller.baseMood == .idle)
    }

    @Test("setOverLimit switches the base mood")
    func setOverLimitSwitchesBase() {
        let controller = MascotController()
        controller.setOverLimit(true)
        #expect(controller.baseMood == .overLimit)
        controller.setOverLimit(false)
        #expect(controller.baseMood == .idle)
    }

    @Test("play ignores base moods")
    func playIgnoresBaseMoods() {
        let controller = MascotController()
        controller.play(.idle)
        controller.play(.overLimit)
        #expect(controller.lastReaction == nil)
    }

    @Test("mood classification: reactions vs base moods")
    func moodClassification() {
        #expect(MascotMood.cashIn.isReaction)
        #expect(MascotMood.cashOut.isReaction)
        #expect(MascotMood.saving.isReaction)
        #expect(MascotMood.goalReached.isReaction)
        #expect(MascotMood.idle.isBase)
        #expect(MascotMood.overLimit.isBase)
    }

    @Test("each reaction maps to its Rive trigger; base moods map to nil")
    func triggerMapping() {
        #expect(MascotRiveInputs.trigger(for: .cashIn) == "cashIn")
        #expect(MascotRiveInputs.trigger(for: .cashOut) == "cashOut")
        #expect(MascotRiveInputs.trigger(for: .saving) == "saving")
        #expect(MascotRiveInputs.trigger(for: .goalReached) == "goalReached")
        #expect(MascotRiveInputs.trigger(for: .idle) == nil)
        #expect(MascotRiveInputs.trigger(for: .overLimit) == nil)
    }

    @Test("Rive input names match the file contract")
    func inputNames() {
        #expect(MascotRiveInputs.fileName == "owl")
        #expect(MascotRiveInputs.stateMachine == "Main")
        #expect(MascotRiveInputs.artboard == "Owl")
        #expect(MascotRiveInputs.overLimitBool == "overLimit")
    }
}

@MainActor
@Suite("Mascot sleep")
struct MascotSleepTests {
    private func utcCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 10; comps.day = 26
        comps.hour = hour; comps.minute = minute
        return utcCalendar().date(from: comps)!
    }

    @Test("night hours sleep, day hours are awake")
    func nightAndDay() {
        func sleeping(at date: Date) -> Bool {
            let c = MascotController(now: { date }, calendar: utcCalendar())
            c.refresh()
            return c.isSleeping
        }
        #expect(sleeping(at: at(22)))        // 22:00 → sleeping
        #expect(sleeping(at: at(5, 59)))     // 05:59 → sleeping
        #expect(!sleeping(at: at(6)))        // 06:00 → awake
        #expect(!sleeping(at: at(20, 59)))   // 20:59 → awake
    }

    @Test("crossing 21:00 while open sleeps; crossing 06:00 wakes")
    func crossings() {
        var now = at(20, 59)
        let c = MascotController(now: { now }, calendar: utcCalendar())
        c.refresh(); #expect(!c.isSleeping)
        now = at(21); c.refresh(); #expect(c.isSleeping)

        var now2 = at(5, 59)
        let c2 = MascotController(now: { now2 }, calendar: utcCalendar())
        c2.refresh(); #expect(c2.isSleeping)
        now2 = at(6); c2.refresh(); #expect(!c2.isSleeping)
    }

    @Test("tap while sleeping wakes and plays no love")
    func tapWakes() {
        let c = MascotController(now: { self.at(22) }, calendar: utcCalendar())
        c.refresh(); #expect(c.isSleeping)
        #expect(c.handleTap() == .wokeUp)
        #expect(!c.isSleeping)
        #expect(c.lastReaction == nil)
    }

    @Test("tap during the wake-up window is ignored")
    func tapDuringWakeIgnored() {
        var now = at(22)
        let c = MascotController(now: { now }, calendar: utcCalendar())
        c.refresh()
        _ = c.handleTap()                       // wake at 22:00
        now = at(22).addingTimeInterval(0.5)    // within the 1.6s window
        #expect(c.handleTap() == .ignored)
        #expect(c.lastReaction == nil)
    }

    @Test("tap while awake plays love; two taps give two reactions")
    func tapPlaysLove() {
        var now = at(12)
        let c = MascotController(now: { now }, calendar: utcCalendar())
        c.refresh(); #expect(!c.isSleeping)
        #expect(c.handleTap() == .love)
        #expect(c.lastReaction?.mood == .love)
        let first = c.lastReaction
        now = at(12).addingTimeInterval(1)
        _ = c.handleTap()
        #expect(c.lastReaction != first)        // restarted
        #expect(c.lastReaction?.mood == .love)
    }

    @Test("after love, the base mood is unchanged")
    func loveKeepsBaseMood() {
        let c = MascotController(now: { self.at(12) }, calendar: utcCalendar())
        c.refresh()
        _ = c.handleTap()
        #expect(c.baseMood == .idle)
        c.setOverLimit(true)
        _ = c.handleTap()
        #expect(c.baseMood == .overLimit)
    }

    @Test("night awake dozes after 60s; activity resets the timer")
    func dozeTimer() {
        var now = at(22)
        let c = MascotController(now: { now }, calendar: utcCalendar())
        c.refresh()
        _ = c.handleTap()                       // wake at 22:00
        #expect(!c.isSleeping)
        now = at(22).addingTimeInterval(60)
        c.refresh()
        #expect(c.isSleeping)                   // dozed off

        var now2 = at(22)
        let c2 = MascotController(now: { now2 }, calendar: utcCalendar())
        c2.refresh()
        _ = c2.handleTap()                      // wake at 22:00
        now2 = at(22).addingTimeInterval(30)
        c2.play(.cashIn)                        // activity resets the timer
        now2 = at(22).addingTimeInterval(70)    // only 40s since the reset
        c2.refresh()
        #expect(!c2.isSleeping)                 // still awake
    }

    @Test("a reaction while sleeping keeps it sleeping")
    func reactionWhileSleeping() {
        let c = MascotController(now: { self.at(22) }, calendar: utcCalendar())
        c.refresh(); #expect(c.isSleeping)
        c.play(.cashIn)
        #expect(c.isSleeping)
        #expect(c.lastReaction?.mood == .cashIn)
    }

    @Test("love maps to its Rive trigger; sleeping boolean name")
    func loveMapping() {
        #expect(MascotRiveInputs.trigger(for: .love) == "love")
        #expect(MascotRiveInputs.sleepingBool == "sleeping")
        #expect(MascotMood.love.isReaction)
    }
}

@Suite("Budget over-limit (mascot)")
struct BudgetOverLimitTests {
    private let tz = "UTC"

    private func octoberPeriod() -> BudgetPeriod {
        PeriodCalculator.period(for: utcDate(year: 2026, month: 10, day: 15), startDay: 1, timeZoneID: tz)
    }

    private func foodBudget(limit: String) -> (Budget_Planner.Category, Budget) {
        let food = Budget_Planner.Category(kind: .expense, defaultKey: "food")
        let budget = Budget(category: food)
        budget.limits = [BudgetLimit(amount: dec(limit), effectiveFrom: utcDate(year: 2026, month: 10, day: 1), budget: budget)]
        return (food, budget)
    }

    @Test("over 100% is over-limit; under is not")
    func overAndUnder() {
        let (food, budget) = foodBudget(limit: "100")
        let period = octoberPeriod()
        let under = [Transaction(kind: .expense, amount: dec("50"),
                                 occurredAt: utcDate(year: 2026, month: 10, day: 5), timeZoneID: tz, category: food)]
        #expect(BudgetService.anyBudgetOverLimit(budgets: [budget], period: period, transactions: under) == false)

        let over = under + [Transaction(kind: .expense, amount: dec("60"),
                                        occurredAt: utcDate(year: 2026, month: 10, day: 6), timeZoneID: tz, category: food)]
        #expect(BudgetService.anyBudgetOverLimit(budgets: [budget], period: period, transactions: over) == true)
    }

    @Test("goal-paid expenses are excluded from the over-limit check")
    func goalPaidExcluded() {
        let (food, budget) = foodBudget(limit: "100")
        let goal = Goal(name: "Trip")
        let period = octoberPeriod()
        let txs = [Transaction(kind: .expense, amount: dec("150"),
                               occurredAt: utcDate(year: 2026, month: 10, day: 5), timeZoneID: tz,
                               category: food, paidFromGoal: goal)]
        #expect(BudgetService.anyBudgetOverLimit(budgets: [budget], period: period, transactions: txs) == false)
    }
}
