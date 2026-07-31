# IntelliSpendIQ — Product Redesign

Derived from the IntelliSpendIQ Flutter Build Spec (Brand Guide v1.0).
This document is the plan of record for the redesign. It is written to be
executed phase by phase; each phase is independently shippable.

---

## 1. Product & UX review of what exists today

The app is functionally rich — capture pipeline, envelopes, transfers, a
ledger-computed balance, an LLM assistant — and visually undifferentiated.
It is `ColorScheme.fromSeed(teal)` with default Roboto and a Card around
everything. The gap is not polish; it is that **the interface does not
express what the product actually does.**

### 1.1 The signature system is invisible

The build spec's centrepiece is *capture and confidence*: three sources
(SMS / voice / manual), three confidence levels (certain / uncertain /
unresolved). None of it renders.

| Spec | Today |
|---|---|
| Source chip with per-source fill and dot | A grey `CircleAvatar` with an icon; no label, no colour distinction |
| Uncertain → **only the guessed field** in `review` colour with a dotted underline | Nothing. A row is either normal or has `needs review` printed in error-red under the amount |
| Raw source text always retrievable | Stored in `raw_captures`, never surfaced from a transaction row |
| Unresolved excluded from balance, counted in a badge | Correct in the data layer; the badge only exists on the Home tab icon |

The consequence: the user cannot tell a figure the app is *sure* about
from one it *guessed*. That is the single most important thing this
interface has to communicate, and it currently communicates nothing.

### 1.2 Money is formatted against the guide, everywhere

`Money.format` emits `ZMW 1,350.00`. The guide requires `K1,350.00` —
symbol `K`, no space, ISO code reserved for statements and export.
Signing is assembled ad hoc at each call site
(`'${isCredit ? '+' : '-'}${Money.format(...)}'`), producing `-ZMW 89.00`
with an ASCII hyphen where the guide requires `−K89.00` with U+2212.
There is no compact form, so chart axes and headline figures print full
ngwee. And because every number renders in the default proportional
Roboto, **amounts in a column do not align on the decimal.**

This is one function and it is wrong in every screen at once, which makes
it the highest-leverage fix in the codebase.

### 1.3 The app's central number does not appear on the home screen

Total balance — which the ledger work now computes properly — is only
visible on the Accounts page. Accounts is reachable at
`Home → Settings → Accounts`: **three taps to answer "how much do I
have?"**, the most common question a finance app is asked. Home instead
opens with a greeting ("Good evening") and a spend-vs-income progress bar.

### 1.4 No visual hierarchy

The Dashboard is six stacked `Card`s of identical weight: greeting,
review banner, quick actions, income overview, top categories, recent
activity. Nothing is primary. The eye has no entry point. The same
flattening happens on Budgets (two summary cards then N envelope cards)
and Reports (four equal cards).

### 1.5 Navigation and IA

- **Four nested `Scaffold`s.** Each tab page builds its own `Scaffold`
  and `AppBar` inside `HomeView`'s `Scaffold`. So there are four different
  app bars with four different action sets, and the Settings gear exists
  only on Home. The app has no consistent chrome.
- **Accounts is filed under Settings.** It owns balances, opening
  balances and the manual transfer entry point. It is a money screen, not
  a preference.
- **Two competing add affordances.** A FAB stack (mic + plus) that
  appears *only* on the Activity tab, and a `QuickActionsRow` of
  Add/Voice/Assistant cards on the Dashboard. Same actions, two
  treatments, and on Budgets or Reports neither is available — you must
  navigate away to record a transaction.
- **Review is only discoverable from Home.** Badge on the Home tab icon,
  banner on the Dashboard. From Activity or Budgets there is no signal
  that anything is waiting.
- **The Assistant has no navigation slot at all.** A marquee LLM feature
  reachable only by finding one card on the Dashboard.
- **Record transfer is four taps deep** (Home → Settings → Accounts →
  app-bar icon) despite being a normal kind of entry.
- **Budgets and Reports overlap** without agreeing. Both are month-scoped
  spend views. Reports has a month stepper; Budgets is hard-locked to the
  current month with no way to look back.

### 1.6 Emoji are the icon system

Ten seeded categories store emoji glyphs (`🍲`, `🚌`, `📱`…) and the
category editor asks the user to *"Paste an emoji, e.g. 🎮"*. The guide
bans emoji outright, including in copy. This is a data-layer change, not
just a rendering one.

### 1.7 Missing states

| State | Today |
|---|---|
| Loading | bare centred `CircularProgressIndicator`, or nothing |
| Error | **does not exist on any screen** — cubits carry status enums that no view renders |
| Empty | inconsistent: Activity has a good one, Reports has a bare sentence with no action, Budgets/Accounts vary |
| Offline / permission-denied | not represented |

### 1.8 Smaller findings

- No touch-target floor is enforced; chart legend rows and the compact
  quick-action cards fall under 48dp.
- Dark mode is `fromSeed(..., brightness: dark)` and keeps Material
  shadows — the guide requires elevation to be surface lightness only.
- No motion language; no `disableAnimations` handling.
- Nothing respects the 200% font-scale requirement; several `Row`s with
  fixed `Text` will overflow.
- The on-device privacy promise — a genuine differentiator — appears
  nowhere in the UI.
- **Savings goals do not exist as a feature.** The requested Phase 7 has
  no code behind it; it is a net-new build, not a redesign.

---

## 2. Information architecture

### 2.1 The four questions

Every screen should answer exactly one:

| Question | Screen |
|---|---|
| How much do I have? | **Home** |
| What happened? | **Activity** |
| Am I on plan? | **Budgets** |
| Where does it go? | **Insights** |

Everything else is a *service* to those four and does not deserve a tab:
Review trends to zero by design, the Assistant is invoked not browsed,
Accounts is entered from the balance, Settings is rare.

### 2.2 Bottom navigation

```
┌──────────────────────────────────────────────┐
│   Home     Activity    ( ＋ )   Budgets  Insights │
└──────────────────────────────────────────────┘
```

Four destinations plus a centre-docked FAB. The FAB is the Create
Transaction action, as requested — it is the single most frequent
deliberate action in the app (SMS capture is the most frequent action
overall, but it requires no UI).

- **Tap** → New entry.
- **Long-press** → Voice capture, with a one-time coach mark on first
  run. Voice also keeps an explicit button on Home and inside the New
  entry screen, so it is never *only* behind a long-press.

### 2.3 Shell app bar

One app bar, owned by the shell, not by each tab. Tab pages become
scroll bodies.

`[ Screen title ]                    [ Review • ] [ Assistant ] [ Settings ]`

The Review action renders only when the count is above zero, carrying the
badge — so the inbox is visible from every tab instead of only Home, and
vanishes entirely when there is nothing to do.

### 2.4 Secondary navigation

| Destination | Reached from |
|---|---|
| Accounts | tapping the balance on Home (primary), Settings (secondary) |
| Account detail | an account row on Accounts |
| Category detail | an envelope on Budgets, a slice on Insights |
| Review inbox | shell app bar badge, Home header strip |
| Assistant | shell app bar |
| Categories, Senders, Data, Security | Settings |

### 2.5 Flows shortened

| Task | Before | After |
|---|---|---|
| See total balance | 3 taps | **0** — on Home |
| Open Accounts | 3 taps | **1** |
| Add a transaction from Budgets/Insights | navigate away first | **1** |
| Record a transfer | 4 taps | **1 tap + a segment** (New entry → Transfer) |
| Open the Assistant | 2 taps, Home only | **1, from anywhere** |
| See what needs review, from Activity | not possible | **visible in the app bar** |

The important structural move: **New entry becomes segmented
Expense / Income / Transfer.** A transfer is a kind of entry, not an
account-management chore, and this removes the deepest flow in the app.

### 2.6 Search and filtering

Search stays on Activity but moves into a collapsing app bar. Filters
stop hiding behind a sheet with a badge and become a horizontally
scrolling chip row (Account · Category · Date · Source) that shows its
own active state, with the sheet reserved for the date range picker.
Discoverability of the current filter state is the problem being fixed;
today an active filter is a single dot on an icon.

---

## 3. Design system

Built first, in `lib/app/theme/` (tokens) and `lib/ui/` (components), so
that no screen work starts before the vocabulary exists.

### 3.1 Colour

Values chosen to satisfy the guide's roles and its contrast rules.
Ratios are against the surface each token is used on.

**Ink (light)**

| Token | Hex | Use | Contrast |
|---|---|---|---|
| `paper` | `#FFFFFF` | card fill | — |
| `ink050` | `#F4F4F3` | app background | — |
| `ink100` | `#E8E8E6` | chip fill, container high | — |
| `ink200` | `#DCDCD9` | card hairline | — |
| `ink300` | `#94948D` | borders, icons **only** | 3.03:1 on white |
| `ink400` | `#6E6E68` | metadata — the text floor | 5.06:1 |
| `ink500` | `#565650` | SMS chip dot | — |
| `ink700` | `#33332F` | chip label | — |
| `ink900` | `#16161A` | primary text | 18.3:1 |

**Night (dark)**

| Token | Hex | Use |
|---|---|---|
| `night900` | `#0F0F12` | app background |
| `night800` | `#17171B` | cards |
| `night700` | `#1F1F25` | sheets, menus, chips |
| `nightLine` | `#35353E` | decorative card hairline |
| `nightLineStrong` | `#6A6A75` | input borders, meaningful dividers — 3.4:1 |
| `nightText` | `#EDEDF0` | primary text |
| `nightText2` | `#A0A0A8` | secondary — 7.4:1 |

**Brand**

| Token | Hex | Rule |
|---|---|---|
| `violet100` | `#EDE9FE` | voice chip fill (light) |
| `violet300` | `#B69CFF` | dark-mode accent, links on dark — **never on a light surface** |
| `violet600` | `#6C3CE9` | primary fill, light — 6.07:1 with white |
| `violet700` | `#5A2FD0` | links, focus ring, light — 7.6:1 |
| `cyan300` | `#4FD8E8` | dark-mode primary — **dark surfaces only**, at most once per screen |

**Money** (`MoneyColors` `ThemeExtension`, so widgets never branch on
brightness themselves)

| Role | Light | Dark |
|---|---|---|
| `inflow` | `#0E7A5F` (5.3:1) | `#4ADE9E` |
| `outflow` | `#B3261E` (6.6:1) | `#FF8A80` (8.3:1) |
| `review` | `#A15C00` (5.2:1) | `#F0B429` |

Outflow is not an alert. Every colour-carrying state also carries a word
— "Over by K240", never red alone.

### 3.2 Typography

IBM Plex, bundled in `assets/fonts/` (1.4 MB, seven faces). Bundled
rather than fetched so the offline-first promise holds literally.

| Role | Face | Size / line |
|---|---|---|
| Balance display | Mono 600 | 34 / 38, −0.02em |
| Screen title | Sans 600 | 24 / 30, −0.01em |
| Section header | Sans 600 | 17 / 24 |
| Row title | Sans 500 | 16 / 22 |
| Row amount | Mono 600 | 16 / 22 |
| Body | Sans 400 | 15 / 23 |
| Metadata | Sans 400 | 13 / 18 |
| Chip / overline | Mono 500 | 11 / 14, 0.08em, uppercase |
| Editorial | Serif 400 / 500 italic | onboarding, insights, wrap only |

13px is the floor; the 11px chip is the sole exception and is always
uppercase and tracked. Every numeric style is Plex Mono, which makes
tabular alignment structural rather than a font-feature flag.

### 3.3 Spacing, radius, motion

- **Spacing**: 4-point scale — 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.
- **Radius**: card 12 · chip full · FAB 18 (`RoundedRectangleBorder`,
  not a circle) · sheet 20 top · input 10 · button 12.
- **Elevation**: light mode uses a 1px hairline plus a single very soft
  shadow; **dark mode is `elevation: 0` everywhere** — depth is surface
  lightness (`night800` on `night900`, `night700` for sheets).
- **Motion**: row arrival 180ms ease-out (fade + 8dp rise) · sheet 240ms
  decelerate · undo snackbar 2,000ms hold then 150ms fade · voice
  listening is one looping amplitude bar · **an amount never animates**.
  All of it gated on `MediaQuery.disableAnimations`.

### 3.4 Component inventory (build order)

Foundation, built before any screen:

1. `MoneyText` — the single amount renderer. Owns sign, colour,
   tabular face, compact mode. No screen formats money itself.
2. `SourceChip` / `ConfidenceMark` — the capture-system vocabulary.
3. `AppCard`, `AppListRow`, `SectionHeader`
4. `AppButton` (primary / secondary / text / destructive), `AppIconButton`
5. `AppTextField`, `AppSelectField`, `AmountField`
6. `AppSheet`, `AppDialog`, `AppSnackbar`
7. `EmptyState`, `LoadingState` (skeletons, not spinners), `ErrorState`
8. `StatTile`, `ProgressMeter`, `ChartFrame`, `Legend`
9. `AppScaffold` — the shared page layout the shell hands to each tab
10. `AppShell` — nav bar, centre FAB, app bar actions

---

## 4. Phased implementation plan

Each phase ships green: `flutter analyze`, full test suite, `dart format`.

| # | Phase | Objective | Depends on |
|---|---|---|---|
| 1 | Design system | tokens, type, `Money`, component library, de-emoji | — |
| 2 | Navigation shell | one app bar, 4 tabs + centre FAB, review everywhere | 1 |
| 3 | Home | balance-first dashboard | 1, 2 |
| 4 | Transaction flows | segmented New entry, confidence rendering on rows | 1, 2 |
| 5 | Accounts | promoted out of Settings, account detail | 1, 2, 4 |
| 6 | Budgets | envelope redesign, month stepper | 1, 2 |
| 7 | Savings goals | **net-new feature** — schema, repo, cubit, UI | 1, 2, 6 |
| 8 | Insights | Reports rebuilt on the chart components | 1, 2 |
| 9 | Settings | regrouped, privacy lockup, profile | 1, 2, 5 |
| 10 | Polish | motion, a11y sweep, 200% font scale, responsiveness | all |

### Phase 1 — Design system

**Objectives** Establish the vocabulary. Change zero screens
structurally; change every screen's appearance.

**Components** All of §3.4.

**Screens affected** All, via theme. No layout rewrites.

**UX improvement** Money finally reads as money and aligns in columns;
light and dark both become legible; emoji leave the product.

**Checklist**
- [ ] `assets/fonts/` + pubspec declaration
- [ ] `tokens.dart`, `MoneyColors` extension, `typography.dart`
- [ ] `AppTheme.light` / `.dark` per the ColorScheme mapping, no dynamic colour
- [ ] `Money.format` → `K1,250.00`; `Money.signed` → `−K89.00` (U+2212);
      `Money.compact` → `K12.5k`
- [ ] Every existing money call site moved onto `MoneyText`
- [ ] Category `icon` column migrated emoji → named icon keys; icon picker
      replaces the emoji text field
- [ ] Contrast sweep; no cyan300/violet300 on any light surface

### Phase 2 — Navigation shell

**Objectives** One chrome. Four destinations. Centre FAB. Review visible
from anywhere.

**Components** `AppShell`, `AppScaffold`, `AppBottomBar`, `CaptureFab`.

**Screens affected** `HomePage`, all four tab pages (their `Scaffold` and
`AppBar` are removed and their bodies hoisted).

**Dependencies** Phase 1.

**UX improvement** Add-from-anywhere; Assistant gets a permanent home;
review badge follows the user; the four app bars collapse into one.

**Edge cases** Deep links must still resolve to the right tab and to
push-only destinations · FAB must not occlude the last list row (bottom
padding budget) · long-press coach mark shows once, persisted in settings
· back button from a pushed route returns to the originating tab.

**Checklist**
- [ ] `AppSection.tabs` → `[home, activity, budgets, insights]`
- [ ] Shell owns `Scaffold`/`AppBar`; tab pages return bodies
- [ ] Centre-docked FAB, radius 18, tap = New entry, long-press = voice
- [ ] Review action in the app bar, badge-driven, hidden at zero
- [ ] `QuickAddButtons` and the Dashboard `QuickActionsRow` retired
- [ ] Deep-link tests still pass

### Phase 3 — Home

**Critique** Opens with a greeting instead of a number; six equal cards;
the balance is absent.

**Redesign** Balance display (Mono 34) as the hero, tappable to Accounts,
with today/this-month deltas beneath. Then, in order: review strip (only
when non-zero), envelope health as a compact meter row, recent activity
as real ledger rows, and one editorial insight in Plex Serif.

**Components** `BalanceHero`, `ReviewStrip`, `EnvelopeMeterRow`,
`ActivityPreview`, `InsightCard`.

**Flow** "How much do I have?" answered at zero taps; Accounts at one.

**Edge cases** No accounts yet · balance negative · no checkpoint set ·
unresolved entries excluded from the figure and said so in words.

### Phase 4 — Transaction flows

**Critique** Add/Edit is a long single-column form; transfer lives in a
different part of the app; the row renders no source or confidence.

**Redesign** `New entry` with an `Expense · Income · Transfer` segment.
Amount first, at display size, with a numeric keypad. Category and
account as chips, not dropdowns. Date defaults to now and collapses.
Ledger rows gain the source chip, per-field uncertainty marking, and
"view original message" for SMS-sourced rows.

**Components** `EntryTypeSegment`, `AmountField`, `ChipPicker`,
`LedgerRow`, `RawMessageSheet`.

**Edge cases** Editing an SMS-captured row must not destroy provenance ·
transfer legs must not reappear as candidates · 200% font scale on the
amount field · receipt attachment on all three entry types.

### Phase 5 — Accounts

**Critique** Buried in Settings; tiles show a raw number with no
indication it is ledger-computed; no per-account history.

**Redesign** Top-level, entered from the balance. Grouped by type with
subtotals. Each row: name, type icon, computed balance, and a checkpoint
note when one is set. New **Account detail** screen: balance, checkpoint
editor with an explanation of what a checkpoint means, and that account's
ledger.

**Edge cases** Provider-linked accounts on restore · last-account
deletion refusal · opening balance vs later checkpoint.

### Phase 6 — Budgets

**Critique** Locked to the current month; envelope cards are undersized
progress bars; over-budget is colour-only in places.

**Redesign** Month stepper matching Insights. Envelope rows as
`ProgressMeter` with remaining-first framing ("K240 left · 9 days"), and
over-budget always worded. Planned-vs-actual promoted to a `StatTile` pair.

### Phase 7 — Savings goals (net-new)

Not a redesign — this feature does not exist. Needs a schema migration
(v8), `Goal` model, repository, cubit, and UI, plus backup/export
inclusion (bumps `_backupSchemaVersion`). Should be specified separately
before it is built.

### Phase 8 — Insights

**Critique** Charts print full ngwee on axes; donut + list duplicate each
other; the month stepper is bespoke; no year view.

**Redesign** Rebuild on `ChartFrame`/`Legend` with `Money.compact` axes.
Category and account breakdowns become one control. Add the trend and
heatmap under a single scoped period control shared with Budgets.

### Phase 9 — Settings

**Critique** Accounts and Categories are filed as preferences; no privacy
statement despite it being the brand's core claim.

**Redesign** Regroup: Money (Categories, Senders) · Data (export, backup,
restore) · Security (lock, PIN, biometrics) · Assistant (API key) ·
About. Accounts leaves for the top level. The on-device lockup appears in
the export sheet, per the guide's three-places rule.

### Phase 10 — Polish

Motion tokens applied · `disableAnimations` honoured · 48dp/8dp sweep ·
200% font-scale pass on ledger and review · landscape and tablet
breakpoints · contrast re-sweep · no amount animates.

---

## 5. Definition of done (from the guide)

- [ ] Light and dark pass a contrast sweep; no cyan300/violet300 on light
- [ ] Colour carries meaning but never stands alone
- [ ] All amounts tabular and decimal-aligned in a column
- [ ] Ledger and review legible and non-clipping at 200% font scale
- [ ] No touch target under 48dp; 8dp minimum separation
- [ ] Unresolved entries excluded from the balance and counted in the badge
- [ ] Uncertain rows mark only the guessed field; raw source always retrievable
- [ ] Every colour-carrying state also carries a word
- [ ] Offline-first; no network required for core function
- [ ] No shadows in dark mode
- [ ] Animations honour the system animation scale; no amount animates
- [ ] No emoji anywhere in UI or copy
