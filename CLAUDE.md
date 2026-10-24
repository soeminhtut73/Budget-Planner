# Pocket Ledger — iOS budget planner (V1)

Personal finance app for users in Southeast Asia (Myanmar, Vietnam, Singapore): track income and expenses across wallets, set monthly budgets, save toward goals, see reports, export data.

V1 is **local-only** (on-device storage, no backend). Loans, shared agreements, the Laravel server, push notifications and iCloud sync are **V2** — but V1 must be built so they can be added without migrating or rewriting data (see "Future-proofing").

---

## How to work in this repo

1. **Plan before code.** At the start of each milestone, write a short plan (files to add/change, models, tests) and wait for my approval before implementing.
2. **One milestone at a time** (see "Build order"). Keep each change small and reviewable.
3. **Every calculation gets unit tests** before its UI is built (balances, budget periods, goal math, time zones, export).
4. **Build and run tests** after every change. Don't report a milestone done while anything fails.
5. **No third-party dependencies without asking.** Prefer Apple frameworks.
6. **Commit per milestone** with a clear message. Never commit secrets.
7. If a rule below is unclear or conflicts with something, **ask** — don't guess. If we make a new decision, add it to "Decision log" at the bottom of this file.

---

## Tech stack

- Swift, SwiftUI, **iOS 18+**
- **SwiftData** for storage, `@Observable` view models (MVVM)
- Swift Charts for reports
- Swift Testing for unit tests
- String Catalog (`Localizable.xcstrings`) for localization
- UserNotifications for local notifications (budget alerts, reminders)

## Code rules

- **Money is always `Decimal`**, never `Double` or `Float`. Amounts are stored as positive numbers; the transaction kind decides the sign.
- Round to the currency's minor units only for display (USD 2 decimals, MMK 0).
- No force unwraps (`!`) outside tests.
- No hardcoded user-facing strings — everything goes through the String Catalog.
- Views stay thin: logic lives in view models and services.
- Format numbers, currency and dates with the user's `Locale`, never by hand.
- All money display goes through `MoneyFormatter` (injected via the `\.money` environment); never hardcode a currency code or symbol in a view. It uses the narrow symbol and the currency's standard minor units; the `+`/`−` sign comes from `AmountText`.

---

## V1 scope

### In V1
- Wallets (Cash, Bank, E-wallet, custom)
- Transactions: add / edit / delete expense and income
- Recurring income (e.g. salary repeats monthly)
- Categories (default + custom), separate for expense and income
- Activity list with filters and search
- Budgets per category (monthly limits) with alerts
- Budget detail with that category's records
- Savings goals with contributions and withdrawals
- Reports (cash flow, spending by category)
- Export: CSV and full JSON backup
- Settings: currency, language, budget month start day, wallets, categories, notifications, Face ID lock
- Localization: English + Burmese (`en`, `my`)
- **Mascot:** V1 ships a non-animated `MascotView` placeholder that reserves its final footprint. The full character (an original character, not an owl) with its 6 states and goal-completed celebration ships in **v1.1** — see "Mascot".

### Not in V1 (V2 and later)
- Loans module and loan calculator
- Shared two-party loan agreements, Laravel backend, live editing
- Push notifications (server-sent)
- iCloud sync
- Hand-drawn Rive mascot replacing the SwiftUI owl (later; same API)
- Budget rollover, multi-currency, shared goals, auto-save rules

---

## Core money rules (do not break these)

These are the agreed model. Every screen and calculation must follow them.

1. **Total balance = sum of all wallet balances.** It is real money.
2. **Wallet balance = opening balance + income − expenses** for that wallet.
3. **Every expense reduces Total balance**, whether or not its category has a budget.
4. **A budget is a spending limit, not money.** It never holds or deducts money. It only measures expenses in its category during the current period. Creating, editing or deleting a budget never changes any balance.
5. **Goals reserve money; they don't move it.** Adding to a goal does **not** change Total balance. It increases that goal's saved amount.
6. **Available = Total balance − reserved goal money** (sum of all goals' saved amounts). Home shows both Total and Available.
7. Withdrawing from a goal lowers reserved money (Available goes up, Total unchanged).
8. **Paying from a goal** (expense marked as paid from a goal) reduces Total balance **and** that goal's saved amount; Available stays the same. Such expenses are **excluded from budget totals** (planned spending shouldn't break a monthly budget) but still appear in Activity and Reports.
9. **Nothing is deleted at a period reset.** Budget "spent" is never stored; it's calculated from transactions in the period's date range.
10. **Only the user deletes records**, always with a confirmation.

### Worked example
| Action | Total | Reserved | Available | Food budget |
|---|---|---|---|---|
| Start | 5,480 | 2,100 | 3,380 | 342 / 400 |
| Expense: Lunch 12.50 (Food) | 5,467.50 | 2,100 | 3,367.50 | 354.50 / 400 |
| Expense: Phone 500 (no budget) | 4,967.50 | 2,100 | 2,867.50 | unchanged |
| Add 100 to goal "Trip to Vietnam" | 4,967.50 | 2,200 | 2,767.50 | unchanged |
| Expense paid from goal: 100 | 4,867.50 | 2,100 | 2,767.50 | unchanged |
| Income: Salary 3,000 | 7,867.50 | 2,100 | 5,767.50 | unchanged |

Add this table as a unit test scenario.

---

## Dates, times and time zones

- Store every transaction and goal entry with:
  - `occurredAt` — when it happened, in **UTC** (user can change the date; defaults to now)
  - `timeZoneID` — the user's time zone at that moment (e.g. `Asia/Yangon`, UTC+6:30)
  - `createdAt`, `updatedAt` — system timestamps, never shown in the UI
- **Which day/month a record belongs to is always decided in its local time zone** (`occurredAt` + `timeZoneID`), never in UTC. Example: 00:30 on 1 Nov in Yangon is 18:00 on 31 Oct UTC — it must count in **November**.
- When the user picks a past date, keep the current time of day.
- Date-only values (goal target date, budget period start) are stored as calendar dates, not timestamps.

## Budget periods

- Default period: **calendar month** (1st to last day).
- Setting "Budget month starts on" (1–28) changes the start day, e.g. 25th → 25 Oct to 24 Nov.
- A change to the start day applies from the **next** period; past periods are not reshuffled.
- Budget limits keep a **history**: each limit has an `effectiveFrom` period. Reports for a past month use the limit that was active then. Editing a limit applies from the current period onward.

## Goal math

- Saved = deposits − withdrawals − amounts paid from the goal
- Progress = saved ÷ target
- Monthly needed = (target − saved) ÷ months remaining until target date (minimum 1). No target date → don't show it.
- Status: "On track" if this month's deposits ≥ monthly needed, else "Behind".
- When saved ≥ target: mark complete, offer to archive.
- Adding to a goal when Available is low: **warn but allow** ("This leaves $40 available").

---

## Data model (SwiftData)

All models: `id: UUID`, `createdAt`, `updatedAt`, `deletedAt` (soft delete, see Future-proofing).

| Model | Key fields |
|---|---|
| **Wallet** | name, type (cash / bank / eWallet / other), openingBalance (Decimal), sortOrder, isArchived |
| **Category** | kind (expense / income), defaultKey (e.g. `food`; nil for custom), customName, iconName, sortOrder, isArchived |
| **Transaction** | kind (expense / income), amount (Decimal, > 0), wallet, category, occurredAt, timeZoneID, note, paidFromGoal (optional), recurringRule (optional) |
| **RecurringRule** | kind, amount, wallet, category, note, frequency (monthly in V1), dayOfMonth, nextOccurrence, isActive |
| **Budget** | category (one active budget per category), alertAt80 (Bool), isArchived |
| **BudgetLimit** | budget, amount (Decimal), effectiveFrom (period start date) |
| **Goal** | name, iconName, targetAmount, targetDate (optional), reminderEnabled, status (active / completed / archived) |
| **GoalEntry** | goal, kind (deposit / withdraw / spend), amount, wallet (optional), occurredAt, timeZoneID, note |
| **AppSettings** | mainCurrency (V1: one currency for the whole app), language, budgetStartDay (default 1), notification toggles, faceIDLock |

Default categories are identified by `defaultKey` and shown via the String Catalog, so they translate. Custom categories store the name the user typed.

The mascot has **no stored data**: its mood is derived at runtime from app events and budget state.

---

## Screens (V1)

Tab bar: **Home · Activity · Plan · Reports**. Settings opens from the Home header. (Loans tab arrives in V2.)

| Screen | Contents |
|---|---|
| **Home** | `MascotView(controller:)` (idle / sad when over limit), Total balance + Available, wallet chips, this month income vs expense, budget alert card (≥80%), add button |
| **Activity** | Search, filter chips (All / Income / Expense / Wallet / Category), records grouped by day with day totals, swipe to edit/delete |
| **Add transaction** | Expense / Income toggle, amount keypad, category, wallet, date, note. Expense: "Paid from: Wallet / Goal". Income: source chips, "Repeat monthly", balance preview (wallet and Total before → after) |
| **Saved confirmation** | Short confirmation card with the mascot reaction (`cashIn` / `cashOut` / `saving`) and "Add another" |
| **Goal completed** | `GoalCompletedView` sheet: mascot `goalReached`, confetti, success haptic, "Archive goal" / "Keep it open" |
| **Plan → Budgets** | Period summary (left, spent of total, days left), one row per budget with progress bar and 80% chip; "Spent outside budgets: $X" line; Add budget |
| **Add / Edit budget** | Category grid (categories with a budget are disabled), monthly limit, recent average hint, alert at 80% toggle, this-month preview, note that budgets don't change balances |
| **Budget detail** | Month switcher (past months), left / spent / %, per-day allowance, pace projection, that category's records, "See all in Activity" (pre-filtered), "Add expense" (category pre-selected), Edit |
| **Plan → Goals** | Total reserved, goal cards (progress, saved of target, date, monthly needed, + Add), New goal |
| **New / Edit goal** | Name, icon, target amount, target date (optional), monthly reminder, optional starting amount + source wallet, preview (monthly plan, Total unchanged, Available before → after) |
| **Goal detail** | Progress, entries list, Add / Withdraw, edit, archive |
| **Reports** | Week / Month / Year, cash-flow bars (6 periods), spending by category donut + list, export button |
| **Settings** | Main currency, language, budget month start day, wallets, categories, notifications, Face ID lock, Export data |

---

## Main workflows

1. **First launch:** choose **currency first** (the first onboarding step, pre-selected from the device region: MM → MMK, VN → VND, else USD) → then language → create first wallet(s) with opening balance → seed default categories → land on Home. Existing installs without a saved currency see the currency step once on next launch.
2. **Add expense:** amount → category → wallet → (optional) date, note, paid from goal → Save → balances, budget and Activity update → confirmation card with mascot `cashOut`. If the save crosses 80% or 100% of a budget, schedule a local notification and show the Home alert card; at 100% the mascot turns sad (`overLimit`).
3. **Add income:** amount → source → wallet → optional "Repeat monthly" → Save → mascot `cashIn`. Recurring rules create the next transaction automatically on its date (on app launch / background refresh) and tell the user it was added.
4. **Edit or delete a record:** from Activity or Budget detail. Editing an old record updates past reports automatically (everything is calculated from records). Delete requires confirmation. Re-check over-limit state afterwards.
5. **Create budget:** pick a category without a budget → limit → save. Spending already in this period counts immediately.
6. **Period change:** nothing is written or deleted; budgets simply count from the new period start (mascot leaves `overLimit` if no budget is over). On the first app open of a new period, show a summary card ("You stayed $378 under budget in October") with a one-tap "Move $X to a goal".
7. **Create goal:** name → target → optional date → optional starting amount from a wallet → save.
8. **Add to / withdraw from goal:** amount + wallet → GoalEntry. Total unchanged, Available changes. Warn if Available would go low. A deposit plays mascot `saving`; if it makes saved ≥ target, show `GoalCompletedView` instead.
9. **Spend from goal:** in Add expense, "Paid from: Goal" → choose goal → expense reduces Total and the goal; excluded from budgets.
10. **Export:** Settings or Reports → choose CSV (date range) or Full backup (JSON) → share sheet.

---

## Mascot (owl)

A teal owl drawn entirely in SwiftUI shapes (no image assets, no dependencies). Files: `Components/MascotView.swift`, `Components/ConfettiView.swift`, `Features/Plan/Goals/GoalCompletedView.swift`.

### States (`MascotMood`)
| State | Animation | Kind | Trigger |
|---|---|---|---|
| `idle` | Breathing, random blinks | Base, loops | Default |
| `cashIn` | Coin drops in from above, smile, hop | Reaction ~1.6s | Income saved (incl. recurring income posted) |
| `cashOut` | Coin flies away, wing waves, shrug | Reaction ~1.8s | Expense saved |
| `saving` | Jar appears, coin drops in, proud nod | Reaction ~2.2s | Goal deposit saved |
| `goalReached` | Wings up, sparkles, 3 hops | Reaction ~2.8s | Goal saved ≥ target (in `GoalCompletedView`) |
| `overLimit` | Sad: droopy wings, sad brows, tears, sway | Base, loops | Any budget at or over 100% this period |

### Rules
- **One `MascotController`** (`@MainActor @Observable`) created at the app root and injected with `.environment`. Views use `MascotView(controller:)`; view models call:
  - `play(.cashIn | .cashOut | .saving | .goalReached)` after a successful save only (never on failure or cancel)
  - `setOverLimit(Bool)` after every budget recalculation (save, edit, delete, period change, app launch)
- Reactions play once, then return to the base mood (`overLimit` if any budget is over, else `idle`). A new reaction cancels the current one.
- Withdrawals and goal spending play no reaction in V1.
- Mascot logic stays out of services: services return results (e.g. `didCompleteGoal`), view models decide which reaction to play.
- **Respect Reduce Motion:** no movement, confetti or loops; show the static pose only.
- Mascot is decorative: `accessibilityHidden(true)`. Never put text inside it (app is bilingual); messages go in normal localized `Text`.
- Mascot artwork colors live in `OwlColors` (same in light and dark mode). App UI colors still come from `Theme`.
- Keep the `MascotView(mood:)` / `MascotView(controller:)` API stable so a Rive `.riv` file can replace the drawing later without changing call sites.
- Tests: `MascotController` returns to base mood after a reaction, `setOverLimit` switches base mood, a new reaction cancels the previous one.

---

## Activity list performance

- Load **50 records per page**, newest first, using a **cursor** (`occurredAt`, then `id`), never page numbers/offsets.
- Load the next page when the user is ~10 rows from the bottom; stop when a page returns fewer than 50.
- Use a lazy list; rows never load receipt images.
- Day headers and month totals come from **separate aggregate queries**, not from summing loaded rows.
- Filters and search run as a new paged query.

---

## Export

- **CSV (transactions):** columns — local date, local time, type, category, wallet, amount, currency, note, paid from goal. Date range picker. Encode **UTF-8 with BOM** so Excel shows Burmese text correctly. Use the user's language for category names, but keep a stable `category_key` column for re-import.
- **Full backup (JSON):** all models, versioned (`"schemaVersion": 1`), with IDs and timestamps. This is the format future import/restore and server migration will read.
- Share through the system share sheet / file exporter. Don't write exports anywhere else.
- Test: export → parse back → values (including Decimal amounts and Burmese text) match exactly.

---

## Localization (English + Burmese)

- All UI text in `Localizable.xcstrings` with `en` and `my`. Use plural variants where counts appear.
- Burmese script is taller and often longer: no fixed-height text containers, test every screen in Burmese and with large Dynamic Type.
- Store text as **Unicode** only. Burmese input may arrive in legacy **Zawgyi** encoding: detect and convert to Unicode before saving free text (notes, custom names). Before adding a library for this, ask me.
- Adding a language later must only require a new String Catalog column.

---

## Visual design

Calm, trustworthy palette. Always pair color with a sign or label (`+ $1,800`, `− $4.50`, "Over 80%"); never rely on color alone.

| Role | Light | Dark |
|---|---|---|
| Primary / Income | `#0F766E` | `#2DD4BF` |
| Expense | `#C2410C` | `#FB923C` |
| Warning | `#A16207` | `#FACC15` |
| Background | `#F7F6F2` | `#111413` |
| Surface | `#FFFFFF` | `#1A1E1D` |
| Text | `#1A1C1B` | `#ECEDEA` |
| Secondary text | `#5B605E` | `#A3A8A5` |
| Border | `#DAD9D3` | `#2C3230` |

(Loans indigo `#4338CA` / `#A5B4FC` is reserved for V2.) Define colors in the Asset Catalog with light/dark variants and expose them through one `Theme` type. Minimum touch target 44pt. Respect Reduce Motion.

- Icons: **SF Symbols** for categories, wallets and tabs. No custom icon sets in V1.
- Buttons: native SwiftUI `Button` with one shared `ButtonStyle` in `Theme`.
- Motion: built-in SwiftUI only (`.contentTransition(.numericText())` for balances, `.symbolEffect`, `withAnimation` on progress bars, `.sensoryFeedback`).
- App icon: the only custom image asset in V1 (built with Icon Composer, light / dark / tinted).

---

## Future-proofing for V2 (build this way now)

- **iCloud sync (SwiftData + CloudKit) rules from day one:** every property optional or has a default, no `@Attribute(.unique)`, all relationships optional. Changing this later forces a data migration.
- `UUID` ids, `createdAt` / `updatedAt` on every model, **soft delete** via `deletedAt` (hard-delete only when purging), so sync and the server can reconcile changes.
- Access data through repository protocols (e.g. `TransactionRepository`) so a server-backed or synced implementation can replace the local one.
- Keep the full JSON backup format as the contract for future server import.
- Keep the `MascotView` / `MascotController` API stable so a hand-drawn Rive mascot (state machine `Main`, triggers `cashIn`, `cashOut`, `saving`, `goalReached`, boolean `overLimit`) can replace the SwiftUI owl. Adding `RiveRuntime` needs approval (third-party dependency).

---

## Suggested structure

```
PocketLedger/
  App/            app entry, root tab view, dependency setup (MascotController lives here)
  Models/         SwiftData models
  Repositories/   protocols + SwiftData implementations
  Services/       BalanceService, BudgetService, GoalService, PeriodCalculator,
                  RecurringService, ExportService, NotificationService
  Features/       Home, Activity, AddTransaction, Plan (Budgets, Goals), Reports, Settings, Onboarding
  Components/     AmountText, ProgressRow, SummaryCard, NumberPad, CategoryIcon,
                  MascotView, ConfettiView
  Resources/      Assets, Localizable.xcstrings
Tests/
```

---

## Build order (milestones)

Each milestone: plan → approval → implement → tests pass → commit.

1. **Foundation:** project setup, Theme, models, repositories, `PeriodCalculator`, `BalanceService`, unit tests for money rules, time zones and periods.
2. **Wallets + onboarding:** first launch flow, wallet CRUD, default categories, Settings shell.
3. **Transactions:** Add expense / income, edit, delete, recurring income, saved confirmation with mascot (`MascotView`, `MascotController`, `cashIn` / `cashOut`).
4. **Activity:** paged list (cursor, 50 per page), day grouping with aggregate totals, filters, search.
5. **Home:** Total + Available, income vs expense, alert card, mascot (idle).
6. **Budgets:** list, add/edit with limit history, Budget detail, 80%/100% local notifications, period summary card, mascot `overLimit`.
7. **Goals:** list, new/edit, add/withdraw, spend from goal, completion (`GoalCompletedView`, confetti, `saving` / `goalReached`), reminders.
8. **Reports:** cash flow, category breakdown, period switcher.
9. **Export:** CSV + JSON backup with round-trip tests.
10. **Localization + polish:** Burmese pass, Dynamic Type, accessibility labels, Face ID lock, dark mode check, Reduce Motion check (mascot + confetti).

## Must-have test scenarios

- The worked example table above, step by step.
- Expense at 00:30 local on the 1st (Asia/Yangon) counts in the new month.
- Budget start day 25: periods 25 Oct–24 Nov; changing it mid-period applies next period.
- Limit changed in December: October report still uses October's limit.
- Expense paid from goal is excluded from its category budget but included in Reports.
- Activity paging: inserting a new record while paging produces no duplicates or gaps.
- Recurring salary on the 31st in a 30-day month posts on the last day.
- CSV/JSON export round-trip keeps exact Decimal amounts and Burmese text.
- Mascot: reaction returns to `idle`, or to `overLimit` while a budget is ≥ 100%; deleting the expense that broke the limit returns it to `idle`.

---

## V2 roadmap (don't build yet)

- **Loans:** borrowed / lent tracking, calculator with five methods (interest-only, flat installment, reducing balance, fixed monthly fee, upfront deduction) showing the real monthly rate, payment schedules.
- **Shared loan agreements:** two-party agreements on a Laravel backend; terms locked after both sign; changes only via amendments the other party approves; immutable version history with hash chain; payments confirmed by the other party.
- **Push notifications** for agreement events (APNs `loc-key` so the device localizes).
- **iCloud sync** for personal data; server live editing for shared data.
- Hand-drawn Rive mascot (design in ArtCraft/Figma → animate in Rive → `.riv`), budget rollover, multi-currency, shared goals.

---

## Open decisions (ask before building these parts)

- Whether goal reminders and recurring income need background refresh or only run on app open.
- CSV import (restore from backup) in V1 or later.
- When to replace the SwiftUI owl with a Rive version, and whether to hire an animator.

## Decision log

- Budget period: calendar month by default; start day changeable in Settings.
- Budgets are limits only; every expense reduces Total balance.
- Goals reserve money; Home shows Total and Available.
- Store `occurredAt` in UTC + `timeZoneID`; group by local date.
- Records are never reset or deleted by the system; budget spent is calculated.
- Activity loads 50 per page with cursor pagination.
- Loans and all server features move to V2.
- Deployment target is **iOS 18+** (raised from 17+).
- Mascot: an **original character** (not an owl), drawn in pure SwiftUI, ships in **v1.1**. V1 uses a non-animated `MascotView` placeholder that reserves its final footprint; the 6 states (idle, cashIn, cashOut, saving, goalReached, overLimit) and `MascotController` move to v1.1. The `MascotView` API is kept stable so the character drops in without changing call sites.
- Mascot moods are driven by one `MascotController`; reactions are one-shot, `idle` / `overLimit` are base moods.
- Goal completion shows `GoalCompletedView` with confetti and success haptic (no assets).
- Icons are SF Symbols; buttons and motion are native SwiftUI; the app icon is the only custom asset.
- Rive is the future path for a richer mascot; no Lottie, no GIFs.
- Approved RiveRuntime (rive-ios) for the owl mascot; SwiftUI owl kept for Reduce Motion. (V1 shipped only the `MascotView` placeholder, so the full mascot system — `MascotController`, `MascotMood`, reactions, `MascotView(controller:)` — was built here with Rive as the renderer. No SwiftUI owl art was ever drawn; Reduce Motion shows a static Rive pose. All owl `.riv` input names live in `MascotRiveInputs`.)
- Currency chosen at onboarding (MMK, VND, USD in V1, list extensible). Narrow symbol. Decimals follow the currency's standard (USD 2, MMK/VND 0), derived from the currency not a hardcoded switch. One `MoneyFormatter` (via `\.money`) formats all money; compact format only in wallet chips and chart labels. Changing currency relabels, doesn't convert existing amounts.
