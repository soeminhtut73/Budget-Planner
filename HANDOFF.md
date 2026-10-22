# Pocket Ledger — handoff / what to build next

_Last commit: `2b3048c` (currency refactor). 64 tests in 11 suites passing. Build + tests only — not yet run in the simulator._

## Done so far
- **M1 Foundation** — models, repositories, `PeriodCalculator`, `BalanceService`, money/period/timezone tests.
- **Phase A** — components (`AmountText`, `SummaryCard`, `CategoryIcon`, `MascotView` placeholder, `NumberPad`, `Chip`, `FlowLayout`, `ProgressBar`, `SegmentedToggle`), `Localizable.xcstrings` (en + my), seeding, DEBUG sample data.
- **M3 Transactions** — add/edit/delete, recurring income, saved confirmation.
- **M4 Activity** — cursor paging, day totals, search, filters, swipe edit/delete.
- **M5 Home** — Total + Available, income vs expense, budget-alert card, recent activity, streak.
- **M6 Budgets** — list, add/edit (limit history), detail, delete (frees category), 80/100% local notifications.
- **M7 Goals** — create/deposit/withdraw/spend-from-goal, detail, completion (confetti + haptic), reminders; Available nets out reserved.
- **M8 Reports** — Week/Month/Year cash-flow bars + spending-by-category donut (Swift Charts).
- **Currency** — one `MoneyFormatter` (`\.money`), currency-first onboarding, Settings currency change.

## Next up (recommended order)
1. **M9 — Export** (the big remaining V1 feature)
   - CSV (transactions): columns per CLAUDE.md, **UTF-8 with BOM**, stable `category_key` column, date-range picker.
   - Full **JSON backup**: all models, `"schemaVersion": 1`, IDs + timestamps (the server-import contract).
   - System share sheet / file exporter. Wire the Reports + Settings **Export** buttons (currently placeholders).
   - **Round-trip tests**: export → parse back → exact Decimal + Burmese text.
2. **M2 completion / Settings substance** (currently mostly "Soon" placeholders)
   - Wallet CRUD + opening-balance editing (WalletsListView is read-only).
   - Category management (add/edit/archive custom categories; currently only inline "+ New" in Add transaction).
   - Budget month start day picker; Notifications toggles; Language.
3. **M10 — Localization + polish**
   - **Burmese UI pass**: translate all the English-only keys added during M3–M8 (most new UI strings are en-only), and resolve the 5 `needs_review` category/wallet strings (`bills`, `fun`, `allowance`, `freelance`, `wallet.ewallet`).
   - **Zawgyi→Unicode** on free text (notes, custom names) — _ask before adding a library_.
   - Dynamic Type, accessibility labels on icon-only buttons, Face ID lock, dark-mode + Reduce-Motion checks.
4. **Mascot v1.1** — real original character + 6 states + `MascotController` (needs design; Rive is a 3rd-party dep → needs approval). API (`MascotView`) is already stable.
5. **Run in the simulator** and capture screenshots (never done yet; USD/MMK screenshots were blocked when device access was declined).

## Engineering gotchas to carry forward
- **SwiftData + Swift Testing**: keep ALL store-backed tests in the single `@Suite(.serialized)` `DataStoreTests` — parallel in-memory `ModelContainer` creation crashes the runner. Tests must **hold the container** (return the container, not just `mainContext`).
- **Test module name clash**: reference the model as `Budget_Planner.Category` in tests (`Category` is ambiguous there).
- **`#Predicate` limits**: can't type-check complex boolean/optional/enum expressions. `ActivityQuery` keeps only the month range in the DB predicate and filters kind/wallet/category/search + cursor in memory. Avoid enum comparisons inside `#Predicate` (filter in memory).
- **Money**: never format money outside `MoneyFormatter`/`AmountText`; views get currency from `\.money`, never a passed code.
- **Toolchain**: only the **iOS 18.1** simulator runtime is installed; tests run on **iPhone SE (3rd generation) 18.1**. Deployment target is **iOS 18**.
- **Mascot**: static placeholder in V1 by decision; confetti + haptics ship, animated reactions are v1.1.
</content>
