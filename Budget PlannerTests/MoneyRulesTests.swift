//
//  MoneyRulesTests.swift
//  Budget PlannerTests
//
//  The worked-example table from CLAUDE.md, step by step. Verifies the Total /
//  Reserved / Available columns. (The "Food budget" column depends on
//  BudgetService and is covered in Milestone 6.)
//

import Testing
import Foundation
@testable import Budget_Planner

@Suite("Core money rules — worked example")
struct MoneyRulesTests {

    @Test("Worked example: Total / Reserved / Available at each step")
    func workedExample() {
        // One wallet holding the starting money. Opening balance chosen so that
        // with no transactions the Total is 5,480.
        let wallet = Wallet(name: "Cash", openingBalance: dec("5480"))

        // A goal already holding 2,100 (one deposit).
        let goal = Goal(name: "Trip to Vietnam", targetAmount: dec("3000"))
        let openingDeposit = GoalEntry(kind: .deposit, amount: dec("2100"), goal: goal)
        goal.entries = [openingDeposit]

        var transactions: [Transaction] = []

        func total() -> Decimal {
            BalanceService.totalBalance(wallets: [wallet], transactions: transactions)
        }
        func reserved() -> Decimal { BalanceService.reserved(goals: [goal]) }
        func available() -> Decimal {
            BalanceService.available(total: total(), reserved: reserved())
        }

        // Start
        #expect(total() == dec("5480"))
        #expect(reserved() == dec("2100"))
        #expect(available() == dec("3380"))

        // Expense: Lunch 12.50 (Food)
        transactions.append(Transaction(kind: .expense, amount: dec("12.50"), wallet: wallet))
        #expect(total() == dec("5467.50"))
        #expect(reserved() == dec("2100"))
        #expect(available() == dec("3367.50"))

        // Expense: Phone 500 (no budget)
        transactions.append(Transaction(kind: .expense, amount: dec("500"), wallet: wallet))
        #expect(total() == dec("4967.50"))
        #expect(available() == dec("2867.50"))

        // Add 100 to goal "Trip to Vietnam" (deposit): Total unchanged, Reserved up
        goal.entries?.append(GoalEntry(kind: .deposit, amount: dec("100"), goal: goal))
        #expect(total() == dec("4967.50"))
        #expect(reserved() == dec("2200"))
        #expect(available() == dec("2767.50"))

        // Expense paid from goal: 100 → a Transaction expense AND a goal spend.
        transactions.append(Transaction(kind: .expense, amount: dec("100"), wallet: wallet, paidFromGoal: goal))
        goal.entries?.append(GoalEntry(kind: .spend, amount: dec("100"), goal: goal))
        #expect(total() == dec("4867.50"))
        #expect(reserved() == dec("2100"))
        #expect(available() == dec("2767.50"))  // Available unchanged

        // Income: Salary 3,000
        transactions.append(Transaction(kind: .income, amount: dec("3000"), wallet: wallet))
        #expect(total() == dec("7867.50"))
        #expect(reserved() == dec("2100"))
        #expect(available() == dec("5767.50"))
    }

    @Test("Total balance is the sum of all wallet balances")
    func totalIsSumOfWallets() {
        let cash = Wallet(name: "Cash", openingBalance: dec("100"))
        let bank = Wallet(name: "Bank", type: .bank, openingBalance: dec("1000"))
        let txs = [
            Transaction(kind: .income, amount: dec("50"), wallet: cash),
            Transaction(kind: .expense, amount: dec("30"), wallet: bank),
        ]
        #expect(BalanceService.walletBalance(cash, transactions: txs) == dec("150"))
        #expect(BalanceService.walletBalance(bank, transactions: txs) == dec("970"))
        #expect(BalanceService.totalBalance(wallets: [cash, bank], transactions: txs) == dec("1120"))
    }

    @Test("A goal-paid expense still reduces Total")
    func goalPaidExpenseReducesTotal() {
        let wallet = Wallet(name: "Cash", openingBalance: dec("200"))
        let goal = Goal(name: "Trip")
        goal.entries = [GoalEntry(kind: .deposit, amount: dec("150"), goal: goal)]
        let txs = [Transaction(kind: .expense, amount: dec("100"), wallet: wallet, paidFromGoal: goal)]
        // Total drops by 100 (real money left the wallet)...
        #expect(BalanceService.totalBalance(wallets: [wallet], transactions: txs) == dec("100"))
        // ...but this test does not also record the goal spend, so reserved is
        // unchanged here; the full round-trip is covered in workedExample().
        #expect(BalanceService.reserved(goals: [goal]) == dec("150"))
    }

    @Test("Soft-deleted transactions are ignored in balances")
    func softDeletedTransactionsIgnored() {
        let wallet = Wallet(name: "Cash", openingBalance: dec("100"))
        let kept = Transaction(kind: .expense, amount: dec("10"), wallet: wallet)
        let removed = Transaction(kind: .expense, amount: dec("40"), wallet: wallet)
        removed.deletedAt = .now
        #expect(BalanceService.walletBalance(wallet, transactions: [kept, removed]) == dec("90"))
    }
}
