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
