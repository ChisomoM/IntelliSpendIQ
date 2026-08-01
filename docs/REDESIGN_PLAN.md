# IntelliSpendIQ — UI/UX Redesign Plan

Status: **proposal, awaiting approval. No code changed.**
Baseline: `main` @ `cbbaa8a`, 199 Dart files, 35 test files.
Source of truth for visual decisions: *IntelliSpendIQ · Flutter Build Spec · derived from Brand Guide v1.0* (referred to below as "the guide").

---

## 0. Decisions taken

| # | Item | Resolution |
|---|---|---|
| **G1** | Token hex values | **Resolved** — full ramp supplied, recorded in §2.1 below. Grid unit is **8dp**, not 4dp. |
| **G2** | Palette conflict (violet guide vs teal screenshots) | **Resolved — violet.** The uploaded screens are not a colour reference at all; they inform layout, hierarchy and density only. The current `0xFF00695C` teal seed is retired. |
| **G3** | IBM Plex not in the repo | **Open.** Proposal: bundle the `.ttf` faces (SIL OFL) rather than `google_fonts`, because §8 requires no network for core function. Needs a yes to put ~1.4 MB of binary in-repo. |
| **G4** | Money format break (`ZMW 1,350.00` → `K1,350.00`) | Proceeding per the guide. Export paths keep `ZMW`. Touches ~30 call sites and several test assertions. |
| **G5** | Savings goals | **Out of scope.** Does not exist in the codebase; scoped separately as a feature build after this effort. Phase list renumbered accordingly. |
| **G6** | Review inbox placement | **Badged entry point on Home**, not a fifth tab. Nav stays four tabs plus the centre FAB. |

---

## 1. Product & UX review

Findings from reading the current code, not from assumption. Each is a specific defect
with a file behind it.

### 1.1 There is no design system at all

`lib/app/theme/theme.dart` is 24 lines. Its own comment says:

> *"App theme. Deliberately plain Material 3 — the value of this app is in the capture pipeline, not the chrome."*

That was a reasonable trade for a build phase and it is now the single biggest source of
the "fragmented" feeling. Consequences visible throughout:

- **Spacing is magic numbers.** `EdgeInsets.all(16)`, `fromLTRB(16, 8, 16, 96)`, `SizedBox(height: 12)`, `height: 20`, `height: 2` — hand-picked per widget, no scale.
- **Radius is re-declared per widget.** `BorderRadius.circular(12)` appears independently in `IncomeOverviewCard`, the Activity search field, and elsewhere. Nothing stops the next one being 8 or 16.
- **No money colours.** Overspend and spend-vs-income both use `colorScheme.error`. With `outflow` now confirmed as `#B91C1C`, red spending is *correct* — the hue marks direction. The defect is narrower than it looks: the code reaches for the **error/alert role** rather than a money role, so genuine failures and ordinary spending are indistinguishable, and there is no `review` amber state at all for uncertain values. §2.4's rule — outflow is not an alert — is about semantics and word-pairing, not hue.
- **No `ThemeExtension`.** Widgets that need semantic colour have nowhere to read it from.
- **Dark mode is whatever `fromSeed` generated.** None of §2.2's rules (no cyan-300 on light, `elevation: 0`, surface-lightness elevation) are expressible, let alone enforced.
- **No typography scale.** Every screen reaches for `theme.textTheme.titleLarge` / `bodySmall` / `headlineSmall` ad hoc. `bodySmall` is 12px in M3 — under the guide's 13px floor — and it is the metadata style used across the dashboard.

### 1.2 Information architecture is the core problem

Current tab bar (`lib/home/view/home_page.dart`): **Home · Activity · Budgets · Reports**.

Everything else is a `Navigator.push` with no persistent entry point:

| Feature | How you reach it today | Depth |
|---|---|---|
| **Review inbox** | Dashboard banner card, or a badge on the *Home* tab icon | 2 |
| **Assistant (chat)** | Dashboard quick-action chip | 2 |
| **Settings** | Gear icon in the Dashboard AppBar only | 2 |
| **Accounts** | Settings → Accounts | 3 |
| **Categories** | Settings → Categories | 3 |
| **Message senders** | Settings → Message senders | 3 |
| **Budget cycle** | Settings → Budget cycle | 3 |

Three separate problems here:

1. **The signature feature is a second-class citizen.** Review inbox is what makes the
   capture pipeline trustworthy — the guide's §5 and §11 both build on it. It has no
   home. Its badge is attached to the *Home* icon, so the count points at a destination
   that is not the inbox.
2. **Accounts is a financial primitive filed under a gear.** It owns opening balances,
   ledger-derived balances, and manual transfers. It is three taps deep behind an icon
   users read as "preferences".
3. **`_destinationFor` throws `UnimplementedError`** for `review`, `chat`, and `settings`.
   The enum knows these are sections; the shell has no slot for them. That is the IA gap
   made literal in code.

### 1.3 The primary action is in three places and absent from two screens

- `QuickAddButtons` (a stacked `FloatingActionButton.small` mic + full-size `+`) renders
  **only when `state.tabIndex == AppSection.activity.tabIndex`**.
- `QuickActionsRow` on the Dashboard offers Add / Voice / Ask as a card mid-scroll.
- On **Budgets** and **Reports** there is no add affordance at all — you must switch tabs
  first.

So "add a transaction", the most frequent action in a spend tracker, costs 1 tap on
Activity, 2–3 on Home (it scrolls), and a tab switch plus a tap elsewhere. Your instinct
to centre it in the nav bar is right, and it also fixes the inconsistency.

### 1.4 Duplicated concepts across screens

- **Period navigation implemented twice, differently.** `BudgetsCubit.shiftPeriod` walks
  budget cycles and labels them `01/07/2026 – 31/07/2026`. `ReportsCubit.shiftMonth`
  walks calendar months and labels them `July 2026`. Same chevron-left/label/chevron-right
  layout, hand-built in both files, different semantics, different formats. A user moving
  between the two tabs is silently looking at different date ranges.
- **Spend-by-category shown three times.** Dashboard `TopCategoriesCard`, Budgets envelope
  list, Reports category breakdown.
- **Four bespoke empty states.** `NoTransactionsYet`, `_NoMatchingTransactions`,
  `NoBudgetsYet`, `InboxZero`, plus Reports' empty state which is a bare centred `Text`.
  No shared component, no consistent illustration/heading/action structure.

### 1.5 Friction in the entry flow

`TransactionEntryPage` (496 lines) is a full-screen push containing a vertical stack of
labelled `TextField`s and two `DropdownButtonFormField`s. Specific costs:

- **Amount is a plain text field** with `prefixText: 'ZMW '` and a regex input filter. The
  most important field on the screen gets the same visual weight as "Description".
- **Date/time costs two modals.** `_pickDate` chains `showDatePicker` then `showTimePicker`
  — for a value that is "now" in the overwhelming majority of manual entries.
- **Category is a flat dropdown** of every category, with a `+` `IconButton` beside it that
  pushes a whole `CategoryEditorPage`. Subcategories exist in the model but the dropdown
  flattens them.
- **Adding a payee or label opens an `AlertDialog`** containing a bare `TextField` — the
  guide prefers sheets, and dialogs here interrupt a form the user is mid-way through.
- **Direction toggle arrows are ambiguous.** `Spent` gets `arrow_upward`, `Received` gets
  `arrow_downward`. In a ledger, money out is conventionally down.

### 1.6 Emoji are in the database, not just the UI

`category_repository.dart` seeds ten categories with emoji icons — 🍲 🚌 🛍 🧾 💰 📱 🏦 📦 🔁 ❓
— persisted into `categories.icon` as text. `category_widgets.dart` has a 🎮 in the picker.
The guide bans emoji outright ("anything with an emoji"), and the screenshots show glyph
icons in tinted rounded containers instead.

This means the emoji swap is **a data migration, not a find-and-replace**: `icon` must hold
a stable string key resolved through an icon registry, with a migration mapping existing
emoji values to keys so users who already customised categories don't lose them.

### 1.7 Missing and weak states

- **Loading is a bare centred spinner** in Dashboard, Budgets, and the Settings data
  section. No skeletons anywhere.
- **Errors are generic snackbars** off `state.errorMessage`. No retry, no typed error
  surface, no distinction between "no API key" and "network failed".
- **No motion.** §7 specifies row-arrival at 180ms ease-out with an 8dp rise, a 2s undo
  snackbar, 240ms sheet open. None of it exists, and nothing reads
  `MediaQuery.disableAnimations`.
- **Voice promises more than it does.** The mic FAB is prominent, but on-device
  transcription is not wired — the sheet takes typed text. The UI should say so rather
  than imply listening.

### 1.8 Accessibility gaps against §11

- `FloatingActionButton.small` is 40dp and `IconButton` defaults to 40dp — **under the 48dp
  floor**, and the two quick-add buttons sit 12dp apart against an 8dp minimum (that one
  passes).
- `bodySmall` (12px) is used for metadata — **under the 13px floor**.
- Nothing tested at 200% font scale. `Row` + `Expanded` + trailing amount `Text` pairs, used
  in every list row and card, will overflow rather than wrap.
- Tabular figures are not enabled, so amounts in a column do not align on the decimal.

---

## 2. Design system — the foundation to build first

New package: `lib/design/`. Nothing outside it may hardcode a colour, a size, a radius, or
a duration. This is the rule that keeps the rest of the work consistent.

```
lib/design/
  tokens/
    colors.dart        raw ramps — the only file with hex literals
    spacing.dart       Space.x1..x10 on a 4pt grid
    radii.dart         Radii.card=12, chip=999, fab=18, sheet=20
    typography.dart    the §3 scale, tabular figures on every numeric style
    motion.dart        durations + curves from §7, reduce-motion aware
    icons.dart         the sanctioned icon set + category-key registry
  theme/
    app_theme.dart     light + dark ThemeData, §2.3 ColorScheme mapping
    money_colors.dart  ThemeExtension<MoneyColors> — inflow/outflow/review
    capture_colors.dart ThemeExtension — source chip + confidence treatments
  format/
    money_text.dart    K-symbol formatting, true minus, compact, tabular widget
  components/
    ... (below)
```

### 2.1 Tokens — confirmed values

The only file in the codebase permitted to contain a hex literal.

**Neutrals — ink (light) / night (dark)**

| Token | Hex | Token | Hex |
|---|---|---|---|
| `ink900` | `#0D173B` | `night900` | `#080D1F` |
| `ink700` | `#1F2A4D` | `night800` | `#101733` |
| `ink500` | `#3A4565` | `night700` | `#1B2447` |
| `ink400` | `#5B6485` | `nightLine` | `#2B3560` |
| `ink300` | `#767E9A` | `nightText` | `#EEF0F7` |
| `ink200` | `#C7CBDA` | `nightText2` | `#A6AECB` |
| `ink100` | `#EEEEF7` | | |
| `ink050` | `#F7F8FB` | | |
| `paper` | `#FFFFFF` | | |

**Action — violet:** `violet700 #5B21B6` · `violet600 #6D28D9` · `violet500 #7C3AED` · `violet300 #9D5BFF` · `violet100 #F3EAFE`

**Graphics only, dark surfaces — cyan:** `cyan700 #055A6B` · `cyan500 #0E9BB5` · `cyan300 #03D8FD` · `cyan100 #DDF7FE`

**Money & state:** `inflow #047857` · `outflow #B91C1C` · `review #B45309` — dark: `inflowD #34D399` · `outflowD #FF9B8F` · `reviewD #F0B429`

**Spacing** — **8dp grid, every value a multiple of 8**: `x1=8, x2=16, x3=24, x4=32, x5=40, x6=48`. Screen gutter `x2`. Card padding `x2`. Gap between cards `x1`. Section gap `x3`.

> This is a real change from the current code, which uses 12dp and 20dp gaps and 2dp/4dp
> nudges throughout (`SizedBox(height: 12)`, `height: 20`, `height: 2`). Every one of those
> is off-grid and will be re-spaced during the component migration.

**Radius** — `card: 12`, `chip: 999` (stadium), `fab: 18` (`RoundedRectangleBorder`, per §6 — not a circle), `sheet: 20` top-only, `input: 12`.

**Touch** — 48dp minimum, 8dp minimum separation.

**Elevation** — light mode: `1px` border + no shadow on cards. Dark mode: `elevation: 0`
everywhere, elevation expressed as surface lightness (`night800` cards on `night900`,
`night700` sheets). Enforced by a single `AppCard` that has no elevation parameter.

**Typography** — the §3 table verbatim, with `fontFeatures: [FontFeature.tabularFigures()]`
on every Mono style. `13px` is the floor; the 11px chip style is the one exception and is
uppercase + `0.08em` tracked.

**Motion** — `Motion.rowArrival = 180ms/easeOut`, `Motion.sheet = 240ms/decelerate`,
`Motion.undo = 2000ms`. A `Motion.of(context)` accessor returns `Duration.zero` when
`MediaQuery.disableAnimations` is set, so no widget branches on it.

### 2.2 Money rendering

A widget, not a string helper — because tabular alignment and sign colouring are rendering
concerns:

```dart
MoneyText(amountMinor, direction: ..., size: MoneySize.row)
```

- Emits `K1,250.00`, `−K89.00` (U+2212), `+K3,000.00`.
- Reads `MoneyColors` from theme; never branches on brightness.
- `MoneySize.display / row / meta`, all tabular.
- `MoneyText.compact` → `K12.5k` for chart axes and headlines.
- `Money.format` stays for CSV/JSON export, where `ZMW` is correct.

### 2.3 Capture & confidence — the signature system

§5 is the most product-specific part of the guide and currently has no UI vocabulary at all.
Three components:

- **`SourceChip`** — `sms` / `voice` / `manual`, with the specified fills and dot colours,
  and dark-mode `night700` + `violet300` variants.
- **`UncertainField`** — wraps only the guessed field in `review` colour with a dotted
  underline. Not the row. Not a badge.
- **`RawSourceSheet`** — the original message text, reachable from any SMS-sourced row.
  §11 requires the raw text always be retrievable; today it is not exposed after capture.

### 2.4 Component inventory — build order within Phase 1

Ordered by how many later phases depend on them.

| # | Component | Replaces | Used by |
|---|---|---|---|
| 1 | `AppScaffold` | ad-hoc `Scaffold` + `AppBar` in 11 screens | every screen |
| 2 | `AppCard` | raw `Card` + hand-rolled `Padding`/`InkWell` | ~20 sites |
| 3 | `MoneyText` | `Money.format` in `Text` | ~30 sites |
| 4 | `SectionHeader` | 3 private copies (`review`, `settings`, inline) | 8 screens |
| 5 | `AppListRow` | bespoke `Row`/`ListTile` mixes | Activity, Budgets, Accounts, Categories, Review |
| 6 | `PeriodSelector` | `BudgetsView` + `ReportsView` duplicates | Budgets, Reports, Dashboard |
| 7 | `EmptyState` | 4 bespoke widgets + 1 bare `Text` | 7 screens |
| 8 | `LoadingSkeleton` | 3 bare `CircularProgressIndicator`s | 5 screens |
| 9 | `ErrorState` | generic snackbars | 5 screens |
| 10 | `AppSheet` | ad-hoc `showModalBottomSheet` in 6 files | all sheets |
| 11 | `AppButton` (primary/secondary/tertiary) | mixed `FilledButton`/`TextButton`/`OutlinedButton` | everywhere |
| 12 | `AppTextField` / `AmountField` | raw `TextField` + `InputDecoration` | entry, editors |
| 13 | `CategoryAvatar` | emoji in a `Text` | Activity, Budgets, Categories, Reports |
| 14 | `ProgressMeter` | raw `LinearProgressIndicator` | Budgets, Dashboard |
| 15 | `SourceChip` / `UncertainField` | nothing — new | Activity, Review |
| 16 | `StatTile` | hand-built `Column`s | Dashboard, Category detail |
| 17 | `DonutChart` / `TrendChart` wrappers | direct `fl_chart` use | Reports, Dashboard |
| 18 | `AppNavBar` + `CenterFab` | `NavigationBar` + `QuickAddButtons` | shell |

Items 1–9 are the hard dependency for everything after Phase 2. I would build and
golden-test those before touching a single feature screen.

---

## 3. Navigation & information architecture

### 3.1 Proposed bottom navigation

**Home · Activity · [ + ] · Budgets · Insights**

with the FAB centred and notched into the bar, per your instinct and screenshots 3 and 5.

Rationale for each change:

- **Review inbox moves out of the nav and into a persistent header entry point on Home**,
  keeping its badge — *but* the badge stops living on the Home tab icon. Screenshot 5 shows
  the alternative (a dedicated `Inbox` tab). I lean against a fifth tab because the inbox
  is aspirationally empty; a permanent tab that says "0" most of the time is dead weight.
  **This is the main IA decision I want your call on** — see the question list at the end.
- **Reports → "Insights"**, absorbing the Assistant. Chat is analysis; reports are analysis.
  Today they are a buried chip and a tab. Merging gives the Assistant a real home and gives
  Insights a reason to be visited more than monthly.
- **Accounts is promoted out of Settings** onto Home as a horizontally scrollable balance
  strip, with the full Accounts screen one tap from it.
- **Settings keeps only settings.** Categories and Message senders stay (they are
  configuration). Budget cycle moves under Budgets, where the period it governs lives.
  Accounts moves to Home.

### 3.2 Depth after the change

| Task | Today | Proposed |
|---|---|---|
| Add a transaction | 1–3 taps, varies by tab | **1 tap, any tab** |
| Voice capture | 1 tap on Activity only | 1 long-press on FAB, any tab |
| Open review inbox | 2 | 1 from Home |
| See account balance | 3 (Settings → Accounts) | 0 — on Home |
| Ask the assistant | 2, Home only | 1 from Insights |
| Change budget cycle | 3 (Settings) | 2 (Budgets → period menu) |
| Retrieve raw SMS for a row | not possible | 2 (row → source) |

### 3.3 FAB behaviour

Centred, `radius: 18`, violet600 / cyan300 per §6.

- **Tap** → Add transaction sheet.
- **Long-press** → radial or sheet with Voice / Scan receipt / Transfer.
- Contextual default per tab: on Budgets it pre-selects the category you were viewing; on
  Accounts it pre-selects that account. Same destination, smarter defaults — this is the
  cheapest friction win in the plan.

### 3.4 Search and filtering

Today search exists only on Activity, as an always-visible `TextField` that eats vertical
space. Proposal: collapse it into the header (icon → expands), keep the filter chip row
from screenshot 4 (`All / Money in / Money out / Notes`) as it is genuinely good, and make
filters visibly stateful with a clear-all affordance.

---

## 4. Phase plan

Each phase is independently shippable and leaves the app in a working state.

### Phase 0 — Decisions & scaffolding
**Objectives:** resolve G1–G5; add font assets; create `lib/design/` skeleton; set up golden
tests infra.
**Screens:** none.
**Dependencies:** your answers.
**Outcome:** unblocks everything.

### Phase 1 — Design system
**Objectives:** tokens, both themes, `MoneyColors`/`CaptureColors` extensions, `MoneyText`,
components 1–13 from §2.4 with goldens in light + dark + 200% scale.
**Screens:** none directly — but `Money.format` call sites migrate, so it touches many files.
**Dependencies:** Phase 0.
**UX improvement:** none visible yet. This is the phase that makes the other nine cheap;
skipping straight to screens is how the current fragmentation happened.

### Phase 2 — Navigation & app shell
**Objectives:** new `AppNavBar` + centre FAB, tab restructure, review-badge relocation,
`AppSection` enum updated so `_destinationFor` no longer throws, deep-link map updated.
**Screens:** `HomePage` shell, every tab's `AppBar` → `AppScaffold`.
**Dependencies:** Phase 1 (items 1, 18).
**UX improvement:** primary action reachable in 1 tap from anywhere; nothing unreachable.

### Phase 3 — Home dashboard ✅ *shipped*
**Objectives:** rebuild as a genuine landing screen — greeting, balance/spend hero, review
entry, account strip, period summary, top categories, recent activity, assistant prompt.
**Screens:** `DashboardPage` + `dashboard_widgets.dart` (360 lines, largely replaced).
**Dependencies:** Phases 1–2.
**UX improvement:** the answer to "how am I doing" without scrolling or tapping.

Delivered, with three changes worth recording:

- **The spend bar was measuring against the wrong number.** It always used planned income.
  A user who had set an overall budget saw Budgets honour it and Home ignore it. `planSource`
  now prefers the period's own budget and falls back to income only when no budget is set —
  see `PlanSource` in `dashboard_state.dart`.
- **`StatTile` was not built.** The hero states its position in a sentence
  ("K240.00 over budget, 9 days left") rather than three tiles, which satisfies the
  colour-never-alone rule better than a tile row. Budgets already has a private `_StatTile`;
  Phase 7 lifts that one into the design system, where screenshot 1 actually calls for it.
- **`ProgressMeter` gained an `onDarkSurface` flag.** The hero card is dark in *both* themes,
  which is the one case `MoneyColors` cannot express — it is keyed on the theme's brightness,
  so in light mode it returns `outflow` (#B91C1C), a dark red that disappears against ink900.
  The flag switches to `outflowD`/`violet300`. The same reasoning already applied to the
  snackbar theme.

`QuickActionsRow` was removed — the centre FAB has owned Add/Voice since Phase 2, and the
Assistant now has its own prompt card with three suggested openers. `ChatPage.route` gained
an `initialPrompt` that fills the input rather than sending, so a mis-tapped suggestion
costs nothing and never silently spends an API call.

### Phase 4 — Transaction flows ✅ *shipped*
**Objectives:** entry becomes amount-first with smart defaults for date, account, category;
payee/label pickers become sheets not dialogs; Activity list adopts `AppListRow` +
`SourceChip` + `UncertainText`; raw-source retrieval added.
**Screens:** `TransactionEntryPage`, `TransactionsPage`, `filter_sheet.dart`,
`transaction_tile.dart`.
**Dependencies:** Phases 1–2.
**UX improvement:** biggest friction win. Target met: amount + 2 taps for the common case.

Entry stayed a **page rather than becoming a sheet**. The form carries ten fields, so a
sheet holding all of them is a page wearing a different hat. The friction came from the
layout, not the surface: amount is now the headline, category is a chip row (filtered to the
chosen direction — the old flat dropdown offered income categories on a debit entry), and
the date defaults to now with Today/Yesterday chips, so the two chained modals only appear
behind "Pick". Account, payee, note, labels and receipt moved behind "More details".

Also landed here:

- **Raw source is reachable at last.** `RawSourceSheet`, from a long-press on any row read
  from a message, or the eye icon when editing one. §11 required it and there was no path to
  it at all — the text was captured and stored but could never be shown again.
- **Two destructive gaps closed:** delete from the entry page fired straight off an app-bar
  icon sitting next to Save with no confirmation, and a part-written entry was discarded
  silently on back. Both now confirm.
- **Day grouping with day totals** on Activity, and a visible All / Money in / Money out
  chip row. Transfers are excluded from a day's net — moving your own money between accounts
  is not income or spending, and counting it would make an ordinary Tuesday look like a
  windfall.
- **A Phase 1 regression found and fixed.** `Category.displayName` returned `'$icon $name'`,
  which was right while `icon` held an emoji. After Phase 1 it rendered **"food Food"** — and
  four of its six call sites are in `FinanceChatService`, so the key was about to be sent to
  the model in the assistant's category payloads.
- **The last emoji surface is gone.** The category editor's "paste an emoji" free-text field
  is now a picker over the icon registry, which also stops arbitrary text reaching a column
  the app reads as an icon key.

### Phase 5 — Review inbox
**Objectives:** promote to a first-class screen; per-section triage; swipe-to-resolve; batch
actions; undo per §7; make the "excluded from balance" contract visible.
**Screens:** `ReviewInboxPage`, `review_tiles.dart`.
**Dependencies:** Phase 4 (shares the entry sheet).
**UX improvement:** the trust loop the whole capture pipeline depends on.

> Note: I have inserted this ahead of Accounts relative to your suggested order, because it
> is the app's differentiator and it currently has the weakest UI. Easy to swap back.

### Phase 6 — Accounts
**Objectives:** promote out of Settings; balance strip on Home; account detail with ledger;
opening balance and transfer flows moved into the standard sheet pattern.
**Screens:** `AccountsPage`, `account_widgets.dart` (525 lines — three sheets to rebuild).
**Dependencies:** Phases 1–3.
**UX improvement:** balances go from 3 taps to 0.

### Phase 7 — Budgets ✅ *shipped* (taken early, at the user's direction)
**Objectives:** apply `PeriodSelector`; envelope cards on `ProgressMeter`; category detail
per screenshot 1; subcategory empty state; budget transfer as a standard sheet; budget
cycle relocated here.
**Screens:** `BudgetsPage`, `CategoryDetailPage`, `budget_widgets.dart`,
`category_detail_widgets.dart`, `income_widgets.dart`.
**Dependencies:** Phases 1–3.
**UX improvement:** one period model shared with Home; no more red-for-normal-spending.

Two judgement calls worth recording:

- **`PlannedVsActualCard` is gone.** It showed Planned and Allocated as peer figures with a
  progress bar underneath and nothing saying which of the two the bar tracked. The
  replacement `BudgetHeroCard` commits to one headline — the budget — and states the
  allocation gap in a sentence beneath it ("K400.00 not yet in a category").
- **Income no longer tracks spend.** `IncomeSummaryCard` used to run its own spend-vs-income
  bar directly under a spend-vs-budget bar. Two bars, same numerator, different denominators,
  one screen — which read as two separate problems. Income is now just the list of what you
  expect to come in, and the hero owns the single spend question.

`BudgetCyclePage` was promoted from Settings to the Budgets app bar, next to the periods it
governs. Its own internals are Phase 9's.

> **Savings goals — out of scope.** Does not exist in `lib/` today. When it is picked up it
> needs a `goals` table carrying `user_id`/`updated_at`/soft-delete to match the sync-ready
> convention every other table follows, plus a repository and three screens. Sequenced after
> this effort, on top of the design system it produces.

### Phase 8 — Insights (Reports + Assistant)
**Objectives:** merge Reports and Chat into one section; chart wrappers on the token
palette; compact money on axes; assistant with suggested prompts per screenshot 3;
propose-and-confirm cards styled properly.
**Screens:** `ReportsPage`, `report_charts.dart`, `day_spend_sheet.dart`, `ChatPage`.
**Dependencies:** Phases 1–3, 7.
**UX improvement:** the Assistant stops being hidden behind a chip.

### Phase 9 — Settings & profile
**Objectives:** slim Settings to actual settings; add the profile surface the screenshots
imply; privacy lockup in exactly the three sanctioned places (§8); copy pass across the
whole app per §9.
**Screens:** `SettingsPage` (579 lines), `CategoriesPage`, `CustomSendersPage`,
`PinSetupPage`, `LockScreenPage`.
**Dependencies:** Phases 1–2, 6, 7.

### Phase 10 — Polish, motion, accessibility, responsiveness
**Objectives:** motion pass per §7; 48dp audit; 200% font-scale pass; contrast sweep; the
§11 definition-of-done checklist enforced in tests where testable.
**Screens:** all.
**Dependencies:** everything.

---

## 5. Per-screen detail

Condensed here; each is expanded when we reach its phase.

### 5.1 Home / Dashboard — Phase 3

**Critique.** `GreetingHeader` shows a raw date range (`01/07/2026 – 31/07/2026`) as
subtitle copy, which is machine output, not a greeting. `ReviewBanner` renders even at zero
(with a `SizedBox` gap conditional on count — so the layout shifts). `QuickActionsRow`
duplicates the FAB's job. `IncomeOverviewCard` turns its progress bar `error`-red on
overspend. There is no balance anywhere on the app's home screen, which for a finance app
is the notable omission. Loading is a bare spinner over the whole page.

**Redesign.** Header (wordmark, review entry with badge, profile). Hero: spend this period
against budget, with `MoneyText` display size and remaining stated in words. Account balance
strip, horizontally scrollable. `PeriodSelector`. Top categories, capped at 4 with "See all".
Recent activity, 5 rows. Assistant prompt row with 3 suggested questions.

**Components.** `AppScaffold`, `StatTile`, `ProgressMeter`, `MoneyText`, `PeriodSelector`,
`CategoryAvatar`, `AppListRow`, `LoadingSkeleton`, `EmptyState`.

**Edge cases.** No income set. No accounts. First launch, zero transactions. Review count
>99. Negative balance. 200% font scale on the hero.

### 5.2 Activity — Phase 4

**Critique.** Search bar is permanently mounted, costing ~72dp above the fold. Filter state
is a `Badge` dot only — you cannot see *what* is filtered without opening the sheet. Rows
carry no source or confidence marking, so SMS-captured and manually-typed entries are
indistinguishable — which directly contradicts §5. Raw SMS text is unreachable. Two
different empty states, neither with a primary action.

**Redesign.** Collapsible search in header. Persistent filter chip row (screenshot 4).
Sticky day headers with day totals. Rows: `CategoryAvatar` + merchant + `SourceChip` +
time + `MoneyText`. Uncertain fields dotted-underlined in `review` colour, row still in
the ledger. Swipe to categorise. Tap-and-hold for raw source.

**Edge cases.** Long merchant names. Same-second transactions. Transfer pairs (must render
as one logical movement, not two rows). Filtered-to-empty. 200% scale — row must wrap, not
truncate the amount.

### 5.3 Add / edit transaction — Phase 4

**Critique.** The single highest-friction flow. Full-screen push for what is a 4-field task.
Amount is a plain field with a `ZMW ` prefix. Date requires two chained modals. Category is
a flat dropdown that discards the subcategory hierarchy the data model supports. Payee/label
creation opens an `AlertDialog` mid-form. Direction arrows point the wrong way for a ledger.

**Redesign.** Bottom sheet. Amount first, large, Mono display size, custom keypad. Direction
as a two-state pill using `outflow`/`inflow` colour *plus* the words "Spent"/"Received".
Merchant with autocomplete from payee history. Category as a horizontal chip row of recent
categories + "More" sheet with hierarchy. Date defaults to now with a "Today / Yesterday /
Pick" row — the two-modal chain only behind "Pick". Account defaults to last used. Save is a
persistent bottom button.

**Target: amount + 3 taps for the common case.**

**Edge cases.** Editing an SMS-captured entry (must not lose the raw link). Resolving from
the inbox. Zero/negative amounts. No accounts configured. Receipt attachment. Unsaved-changes
dismissal.

### 5.4 Review inbox — Phase 5

**Critique.** Structurally the best screen in the app already — four clearly-labelled
sections with genuinely good explanatory subtitles. Weaknesses: no counts per section, no
batch actions, resolution requires a full page push per item, `InboxZero` is a dead end,
and the "unresolved entries are excluded from the balance" contract (a §11 requirement) is
never stated on screen.

**Redesign.** Keep the four sections. Add per-section counts, collapsible groups,
swipe-to-resolve, batch confirm for duplicates, inline category assignment for
needs-a-detail, always-visible raw text on could-not-read, and one line stating the
excluded-from-balance rule. `InboxZero` gets the "Nothing leaves this phone" lockup — one of
its three sanctioned placements.

**Edge cases.** 100+ items. Resolving the last item (celebrate, don't just empty). Undo
window. Item resolved on another surface while open.

### 5.5 Budgets — Phase 7

**Critique.** Period nav hand-built inline. `PlannedVsActualCard`, `IncomeSummaryCard`, and
the envelope list are three different card idioms stacked. "Add category budget" hidden as
an AppBar `+`. Spend amounts use `colorScheme.error` rather than the `outflow` money role,
so ordinary spending and genuine failure states share a colour with nothing to tell them
apart. `NoBudgetsYet` is one of the four unshared empty states.

**Redesign.** `PeriodSelector` at top. Total-budget hero (screenshot 2's dark card is the
right idea, in violet/ink not teal). Income group. Category envelopes on `ProgressMeter`,
outflow colour for direction only, over-budget always paired with words —
"K240 over, 9 days left". "Add category" as a full-width row at the list end, not an AppBar
icon.

**Edge cases.** No budget set. Over budget. Carry-over from prior period. Period with no
transactions. Subcategory totals exceeding the parent (screenshot 1's "Total subcategories
budgeted" row).

### 5.6 Category detail — Phase 7

Screenshot 1 is close to right already: three stat tiles, a donut, budget transfer, and a
subcategory list. Fixes needed: stat tile amounts use alarm-red for ordinary spend; percent
ring should not animate its number (§7 — never animate an amount); `ZMW 50.00` → `K50.00`;
the empty subcategory state duplicates its CTA (a dashed card *and* a header link).

### 5.7 Accounts — Phase 6

**Critique.** Buried at depth 3. `account_widgets.dart` is 525 lines containing three
separate `StatefulWidget` sheets (`AccountEditorSheet`, `BalanceEditorSheet`,
`RecordTransferSheet`), each with its own layout conventions. Balances are computed from the
ledger — a genuinely good decision — but that fact is invisible to the user, so an
unexpected balance looks like a bug rather than a consequence of an unresolved capture.

**Redesign.** Promoted to Home strip + full screen. Account cards with type icon, name,
balance, and last-activity. Detail view with a filtered ledger. The three sheets rebuilt on
`AppSheet`. A line explaining balance is derived from the ledger, with unresolved items
called out.

**Edge cases.** Zero accounts. Negative balance. Account with unresolved captures affecting
its balance. Deleting an account with transactions.

### 5.8 Insights — Phase 8

**Critique.** Reports duplicates Budgets' period navigation with different semantics (month
vs cycle) and a different label format — a real correctness-of-understanding problem, not
just cosmetic. Empty state is a bare centred `Text`. Charts use `fl_chart` defaults, off-
palette. Chat is unreachable except from one Dashboard chip, and its propose-and-confirm
cards — the most interesting interaction in the app — are unstyled.

**Redesign.** One section, two modes. Shared `PeriodSelector` with the same semantics as
Budgets. Chart wrappers on the token palette with `MoneyText.compact` axes. Assistant with
suggested prompts and properly designed confirmation cards that make the "nothing is written
until you tap" contract legible.

**Edge cases.** No data for period. Single-category month. No API key configured. Assistant
offline. Long assistant responses. Proposal declined.

### 5.9 Settings & profile — Phase 9

**Critique.** 579 lines, six sections, and a mix of navigation (Accounts, Categories,
Senders, Budget cycle), actions (export, backup, restore), and configuration (theme, lock,
API key). Reachable only from the Dashboard AppBar. `_DataSection` shows a `CircularProgress`
inline under the list during export with no progress detail. No profile surface exists
despite the screenshots showing an avatar.

**Redesign.** Profile header. Groups: Money (categories, senders — budget cycle leaves for
Budgets, accounts leaves for Home), Data & privacy (with the sanctioned lockup on the export
sheet), Security, Assistant, About. Destructive and long-running actions get confirmation
and real progress.

---

## 6. Testing & definition of done

- Golden tests for every design-system component in **light, dark, and 200% text scale**.
- A contrast test asserting §2.2 mechanically: no `cyan300`/`violet300` resolved against any
  light surface.
- A widget test per screen asserting no overflow at `textScaleFactor: 2.0`.
- A lint or test asserting no `Color(0x...)` outside `lib/design/tokens/`.
- The 35 existing tests must stay green; money-format assertions update in Phase 1.
- §11's checklist tracked per phase, not deferred to the end.

---

## 7. Open questions

Settled: palette (violet), tokens (§2.1), inbox placement (Home entry), savings goals (out).

1. **G3 — bundle IBM Plex `.ttf` in-repo?** ~1.4 MB of binary. The alternative,
   `google_fonts`, fetches over the network on first use, which contradicts §8's
   "no network permission required for core function". I recommend bundling.
2. **Assistant merged into Insights, or given its own tab?** Merging is what §3.1 assumes.
   Its own tab would mean five slots plus the centre FAB.
3. **Phase order** — I moved Review inbox ahead of Accounts (Phase 5 vs 6). Keep, or revert
   to your original order?
4. **Third-party icon set, or Material Symbols?** §2.1's iconography requirement is
   satisfiable with Material Symbols (already available, no new dependency) or a bundled set
   like Lucide/Phosphor, which reads closer to the uploaded screens. Affects the emoji
   migration in Phase 1.
