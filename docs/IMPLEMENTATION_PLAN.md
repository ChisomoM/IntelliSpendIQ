# IntelliSpendIQ — Implementation Plan

> **Status:** Planning complete — do not implement until this document is approved.  
> **Last updated:** 2026-07-28  
> **Scope:** Phase 0 foundation + Phase 1 MVP (core capture loop)

---

## Table of Contents

1. [Product Summary](#1-product-summary)
2. [Priorities & Principles](#2-priorities--principles)
3. [Decisions Log](#3-decisions-log)
4. [Current Codebase State](#4-current-codebase-state)
5. [Architecture Overview](#5-architecture-overview)
6. [Local Data Model (Schema)](#6-local-data-model-schema)
7. [Capture Strategy (Hybrid SMS + Notifications)](#7-capture-strategy-hybrid-sms--notifications)
8. [SMS Sample Corpus & Parser Specs](#8-sms-sample-corpus--parser-specs)
9. [Voice Entry Pipeline](#9-voice-entry-pipeline)
10. [Review Inbox & Duplicate Detection](#10-review-inbox--duplicate-detection)
11. [Budgets & Reports](#11-budgets--reports)
12. [AI Provider Abstraction](#12-ai-provider-abstraction)
13. [Security](#13-security)
14. [Sync & Auth (Deferred)](#14-sync--auth-deferred)
15. [Phase Breakdown & Build Order](#15-phase-breakdown--build-order)
16. [Definition of Done — Phase 1](#16-definition-of-done--phase-1)
17. [Risks & Mitigations](#17-risks--mitigations)
18. [Explicit Non-Goals](#18-explicit-non-goals)
19. [Open Items (Can Wait)](#19-open-items-can-wait)
20. [Phase 2–4 Roadmap (Reference Only)](#20-phase-2–4-roadmap-reference-only)
21. [Appendix](#21-appendix)

---

## 1. Product Summary

**IntelliSpendIQ** is an AI-powered personal finance tracker built with **Flutter**, targeting **Android first**.

**Core problem:** Eliminate friction of manual expense entry by capturing transactions from **SMS alerts** and **voice**, using AI only where it adds real value over deterministic code.

**Primary users (Phase 1):** Solo developer + a few friends, distributed via **sideload / APK only** (no Play Store yet).

**Geography / currency context:** Zambia — **ZMW** (ngwee as minor units).

---

## 2. Priorities & Principles

Priority order (non-negotiable):

1. **Reliability of data capture** — never silently drop a financial event
2. **Low-friction daily use** — auto-save when confident; human glance only when needed
3. **Privacy** — local-first, encrypted DB, strip PII before LLM calls
4. Everything else

### AI usage rules (all phases)

| Use deterministic code | Use LLM | Use embeddings (later) |
|---|---|---|
| SMS parsing | Voice → structured transaction JSON | Merchant similarity |
| Storage, budgets, reports math | New-merchant categorization (Phase 2) | Semantic search (Phase 3) |
| Recurring detection (Phase 2) | Coaching / NL query / OCR (Phase 3+) | |
| Forecast numbers (moving avg / trend) | Narrating forecasts in natural language | |

- **Merchant-alias lookup before any categorization LLM call** (Phase 2).
- **No agents** in Phase 1–3.

---

## 3. Decisions Log

### 3.1 Product & distribution

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| D01 | Platform | Flutter, Android-first | Existing template; personal Android devices |
| D02 | Distribution (Phase 1) | **Sideload / APK only — no Play Store** | Small private user group; unlocks `READ_SMS` without default-SMS-app requirement |
| D03 | Play Store later | Possible later; design hybrid so NotificationListener remains available | Avoid painting into a corner |
| D04 | Default SMS app pivot | **No** | Out of product scope |
| D05 | Multi-device sync | **Single-device fine for Phase 1** | Defer PowerSync / Supabase until local loop trusted |
| D06 | Currency | **Konly** for now | Matches real SMS corpus |
| D07 | Default account | **One mobile-money account** day one; schema supports expansion | Matches Airtel Money as primary capture source |
| D08 | Voice language | **English only** | Simplifies Whisper model choice |
| D09 | Voice auto-save threshold | **0.85** | Conservative; uncertain → review inbox |
| D10 | Claude / network | **Online required** for Claude extraction | Acceptable; queue offline voice for later extraction or leave in inbox |
| D11 | Firebase | **Ignore for now** | Do not invest in Firebase; strip or leave inert in Phase 0 |
| D12 | Min Android API | **Suggest API 26 (Android 8.0)** until measured | Good baseline for Keystore + notifications; revisit if friends need older |

### 3.2 Capture

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| D20 | Capture strategy | **Hybrid** | SMS primary (confirmed source); NotificationListener as secondary / future Play Store path |
| D21 | Primary channel (Phase 1) | **SMS via Android `Telephony.Sms` content provider** + platform channel | User confirmed alerts arrive as SMS |
| D22 | Secondary channel | **NotificationListenerService** (optional / feature-flagged) | Future-proof; useful if some alerts are push-only |
| D23 | Unparseable SMS | **Always store as raw capture** — never drop | Data-trust requirement |
| D24 | Providers (Phase 1) | **Airtel Money** + **Standard Chartered (StanChart)** | Real daily sources |
| D25 | Sender IDs | See [§8.1](#81-sender-ids) | Exact strings for routing parsers |

### 3.3 Persistence & sync

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| D30 | Offline-first | **Mandatory** — app fully usable offline for add / budgets / reports | Core architecture |
| D31 | Local DB | **SQLite + SQLCipher via Drift** | Typed queries; encryption from day one |
| D32 | Encryption timing | **Day one with schema bootstrap** — not step 11 | Avoid painful unencrypted→encrypted migration |
| D33 | Source of truth | Local SQLite for all reads/writes | Sync additive, never blocking (when added) |
| D34 | Sync backend (future) | **Supabase (Postgres)** + evaluate **PowerSync first** (avoid ElectricSQL — no Flutter SDK) | Matches original architecture intent |
| D35 | Conflict resolution (future) | Last-write-wins by `updated_at` | No CRDTs |
| D36 | Multi-tenancy | `user_id` on every table from day one; local UUID until auth exists | Avoid schema migration when friends onboard |
| D37 | Phase 1 sync | **Deferred** — design schema for sync; do not wire PowerSync until Phase 1a–1e work offline | Debug local and sync separately |

### 3.4 Auth & secrets (future / partial)

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| D40 | Auth (when sync lands) | Supabase Auth (email/password or magic link) | Ownership across devices |
| D41 | Secrets storage | Android Keystore via `flutter_secure_storage` | DB passphrase, session tokens |
| D42 | Anthropic API key | **Prefer thin backend proxy** for production; client Keystore OK for private sideload v0 | Embedded keys are extractable; private APK risk accepted short-term |
| D43 | LLM provider | **Claude via Anthropic API** behind `AiProvider` abstraction | Swappable without touching business logic |

### 3.5 Voice & AI

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| D50 | Transcription | Prefer **whisper.cpp on-device** (`tiny`/`base`); API fallback if accuracy insufficient | Privacy + offline transcript |
| D51 | Extraction | Single scoped Claude call → JSON schema | Tight, testable |
| D52 | Default payment method | `"cash"` when unspecified | Voice often means cash |
| D53 | Confirmation UX | Auto-save ≥ 0.85; else review inbox — **no confirm-every-entry** | Low friction |

### 3.6 Amounts & money math

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| D60 | Storage | **Integer minor units** (`amount_minor`) — ngwee (1 K= 100) | Avoid float rounding bugs |
| D61 | Display | Format as `Kx.xx` in UI | Existing template already hardcodes K|

### 3.7 Approach ratings (from architecture review)

| Approach | Rating |
|---|---|---|
| Hybrid SMS + NotificationListener (sideload) | **Recommended** |
| Telephony.Sms only | **Viable** |
| NotificationListener only | **Viable** (secondary for now) |
| Telephony.Sms on Play Store | **Avoid** (until product pivots) |
| PowerSync + Supabase + Drift | **Recommended** (when sync needed) |
| ElectricSQL | **Avoid** (no Flutter SDK) |
| Custom sync engine | **Avoid** for Phase 1 |
| Drift + SQLCipher from day one | **Recommended** |
| whisper.cpp on-device Phase 1 | **Viable** |
| Claude key only in client long-term | **Avoid** — proxy later |

---

## 4. Current Codebase State

**Repo:** `C:\Work\Programming\IntelliSpendIQ`

| Area | Reality |
|---|---|
| Template | Very Good Core (`c_template_app`), Flutter **^3.35**, Dart **^3.9**, BLoC, 3 flavors |
| Package ID | Still `com.example.verygoodcore.c_template_app` |
| MainActivity | Stock `FlutterActivity` — **no platform channels** |
| Auth | Firebase Auth (+ Google/Apple) — **conflicts with future Supabase plan** |
| Local DB | GitLab `local_data` wrapping **sqflite**; schema is `users` / `providers` / `plans` — **unrelated** |
| Permissions | `permission_client` — notifications + location only |
| Currency widget | Hardcoded **ZMW** |
| Idempotency helper | Exists (`lib/utils/idempotency_key.dart`) — rework for finance IDs |
| Finance domain | **None** — no transactions, parsers, voice, budgets, Drift, SQLCipher, Supabase, PowerSync |

**Reusable:** Flutter scaffold, BLoC pattern, flavors, CI, repository package layout, permission client shell, Kdisplay concept.

**Must replace / build:** Persistence layer, auth path (later), entire finance domain, native SMS/notification bridge, parsers, voice, review inbox, budgets, reports, encryption.

---

## 5. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter (Dart)                          │
│  UI (BLoC)  →  Domain services  →  Repositories                 │
│       │              │                                          │
│       │              ├─ CaptureService                          │
│       │              ├─ ParserRegistry (Airtel, StanChart, …)   │
│       │              ├─ DedupeService                           │
│       │              ├─ VoicePipeline                           │
│       │              ├─ BudgetService / ReportService           │
│       │              └─ AiProvider (Claude impl)                │
│       │                                                         │
│       └─ Drift DB (SQLCipher)  ← source of truth                │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Platform channels
┌───────────────────────────▼─────────────────────────────────────┐
│                     Android (Kotlin)                              │
│  SmsInboxBridge  → content://sms/inbox + SMS_RECEIVED            │
│  NotificationCaptureService (optional) → NotificationListener    │
│  SecureStorage → Android Keystore                                │
└─────────────────────────────────────────────────────────────────┘

Offline path: SMS/voice → raw_captures → parse → transactions / review
Online path (optional): Claude extraction for voice; future sync
```

### Core capture loop

```
capture → persist raw → parse/classify → dedupe → route
  → auto-save (confirmed) OR review inbox (needs_review)
  → budgets/reports update live from local SQL
```

### Layering rules

- Feature code never imports Anthropic SDK directly — only `AiProvider`.
- Parsers never write UI state — they return `ParseResult` / `TransactionDraft`.
- Native Android only captures + forwards bytes/text; **all parsing stays in Dart** so unit tests do not need a device.

---

## 6. Local Data Model (Schema)

Design schema **before UI**. All tables include sync-ready columns from day one even though sync is deferred.

### 6.1 Common columns

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID v4 |
| `user_id` | TEXT NOT NULL | Local UUID until Supabase Auth |
| `created_at` | TEXT NOT NULL | ISO-8601 UTC |
| `updated_at` | TEXT NOT NULL | ISO-8601 UTC; LWW field later |
| `deleted_at` | TEXT NULL | Soft delete |

### 6.2 Tables

#### `accounts`

| Column | Type | Notes |
|---|---|---|
| `name` | TEXT | e.g. "Airtel Money" |
| `type` | TEXT | `cash` \| `bank` \| `mobile_money` \| `card` |
| `currency` | TEXT | default `ZMW` |
| `is_default` | INTEGER | bool |
| `provider_key` | TEXT NULL | `airtel_money` \| `stan_chart` \| null |
| `balance_minor` | INTEGER NULL | optional cached balance from SMS (informational) |

**Day-one seed:** one `mobile_money` account named "Airtel Money", `provider_key=airtel_money`, `is_default=1`. StanChart can map to a second account when first parsed SMS arrives or via settings.

#### `categories`

| Column | Type | Notes |
|---|---|---|
| `name` | TEXT | |
| `icon` | TEXT NULL | |
| `color` | TEXT NULL | |
| `parent_id` | TEXT NULL | |
| `is_system` | INTEGER | seeded defaults |
| `sort_order` | INTEGER | |

**Seed examples (editable):** Food, Transport, Airtime/Data, Transfers, Shopping, Bills, Income, Fees/Charges, Uncategorized, Other.

#### `transactions`

| Column | Type | Notes |
|---|---|---|
| `account_id` | TEXT NOT NULL | FK accounts |
| `category_id` | TEXT NULL | nullable until assigned |
| `amount_minor` | INTEGER NOT NULL | absolute amount in ngwee |
| `currency` | TEXT | `ZMW` |
| `direction` | TEXT | `debit` \| `credit` |
| `merchant` | TEXT NULL | counterparty / till / merchant |
| `description` | TEXT NULL | |
| `transacted_at` | TEXT NOT NULL | ISO-8601 |
| `source` | TEXT | `manual` \| `sms` \| `notification` \| `voice` |
| `confidence` | REAL NULL | 0.0–1.0 |
| `status` | TEXT | `confirmed` \| `needs_review` \| `duplicate_suspect` |
| `raw_capture_id` | TEXT NULL | FK raw_captures |
| `idempotency_key` | TEXT UNIQUE | e.g. provider TID / content hash |
| `duplicate_of_id` | TEXT NULL | |
| `payment_method` | TEXT NULL | `cash` \| `mobile_money` \| `card` \| `bank` \| … |
| `external_ref` | TEXT NULL | TID / bank ref |
| `metadata_json` | TEXT NULL | |

**Indexes:**

- `(user_id, transacted_at)`
- `(user_id, status)`
- `(idempotency_key)` UNIQUE
- `(amount_minor, merchant, transacted_at)` for fuzzy dedupe support

#### `budgets`

| Column | Type | Notes |
|---|---|---|
| `category_id` | TEXT NOT NULL | |
| `period` | TEXT NOT NULL | `YYYY-MM` |
| `amount_minor` | INTEGER NOT NULL | monthly limit |
| `carry_over` | INTEGER | whether next month defaults from this |

Unique: `(user_id, category_id, period)`.

#### `raw_captures`

| Column | Type | Notes |
|---|---|---|
| `source_channel` | TEXT | `sms_inbox` \| `notification` \| `voice_transcript` |
| `sender` | TEXT NULL | SMS address / package name |
| `body` | TEXT NOT NULL | **never drop** |
| `received_at` | TEXT | |
| `android_sms_id` | TEXT NULL | native SMS `_id` for backfill dedupe |
| `package_name` | TEXT NULL | for notifications |
| `parse_status` | TEXT | `pending` \| `parsed` \| `failed` \| `ignored` |
| `parser_key` | TEXT NULL | `airtel_money` \| `stan_chart` |
| `error` | TEXT NULL | |
| `parsed_transaction_id` | TEXT NULL | |
| `content_hash` | TEXT | hash(sender + body + received_at bucket) |

#### `review_queue` (optional table vs status flag)

Prefer **`transactions.status = needs_review`** plus raw_captures with `parse_status=failed` surfaced in one inbox UI. If a separate queue is clearer:

| Column | Type | Notes |
|---|---|---|
| `transaction_id` | TEXT NULL | |
| `raw_capture_id` | TEXT NULL | |
| `reason` | TEXT | `parse_failed` \| `low_confidence` \| `missing_fields` \| `uncategorized` \| `duplicate_suspect` |
| `resolved_at` | TEXT NULL | |
| `resolution` | TEXT NULL | |

#### Future (Phase 2 — do not build yet)

- `merchant_aliases` (merchant_key → category_id, confidence, hit_count)

### 6.3 Money encoding examples

| Display | `amount_minor` | `direction` |
|---|---|---|
| K10.00 payment | `1000` | `debit` |
| K300 received | `30000` | `credit` |
| K1350.00 received | `135000` | `credit` |
| Charge K0.00 | store as fee line only if non-zero; ignore zero charges |

---

## 7. Capture Strategy (Hybrid SMS + Notifications)

### 7.1 SMS path (primary) — confirmed

Flutter cannot read SMS itself. Use a **platform channel** into Android:

1. **Kotlin bridge** queries `content://sms/inbox` (`Telephony.Sms`).
2. Optional `BroadcastReceiver` for `SMS_RECEIVED` / `SMS_PROVIDER_CHANGED` to enqueue new messages while app runs (and a WorkManager/boot-safe path if needed for reliability).
3. Dart receives `{ id, address, body, date }` payloads.
4. Dart immediately inserts into `raw_captures`, then runs parser registry asynchronously.

**Permissions (sideload builds):**

- `READ_SMS`
- `RECEIVE_SMS` (if using broadcast)
- Runtime permission request on onboarding

**Play Store note:** This path will **not** ship to Play Store without becoming default SMS/Assistant handler. NotificationListener remains the Play Store-compatible path later. Hybrid keeps both.

### 7.2 NotificationListener path (secondary)

1. Kotlin `NotificationListenerService` with `BIND_NOTIFICATION_LISTENER_SERVICE`.
2. Filter by package / title / text heuristics (banks, messaging).
3. Forward to same `raw_captures` pipeline with `source_channel=notification`.
4. Onboarding: deep-link user to Notification Access settings (cannot auto-grant).

**Android 15+ risk:** sensitive notification redaction may hide body text. SMS remains primary mitigation for this user group.

### 7.3 Platform channel sketch

```
MethodChannel: com.intellispendiq/capture
  - requestSmsPermission()
  - hasSmsPermission()
  - readInboxSince(timestampMs | androidSmsId)
  - requestNotificationAccess()
  - isNotificationAccessGranted()

EventChannel: com.intellispendiq/capture_events
  - onSmsReceived
  - onNotificationReceived
```

### 7.4 Onboarding flow (Phase 1)

1. Create local `user_id` + default Airtel Money account.
2. Request SMS permission → explain why (auto-import bank/mobile money alerts).
3. Optional: enable notification access.
4. Backfill recent inbox (e.g. last 30 days) for known senders only.
5. Land on Review Inbox if any failed/pending items.

---

## 8. SMS Sample Corpus & Parser Specs

### 8.1 Sender IDs

| Provider | Alphanumeric sender | Numeric sender |
|---|---|---|
| Airtel Money | `AirtelMoney` | `24783566639` |
| Standard Chartered | `StanChartZM` | `78262427896` |

Parser routing: match `address` (normalized, strip `+`, spaces) against either form before attempting body regex.

### 8.2 Canonical sample messages (as provided)

#### Airtel Money — Payment (till, named)

```
Payment of K10.00 Till Number SOCHESCARE AIRTEL NETWORKS SELF CARE SOCHE. Airtel Money bal is K45.23. TID : MP260728.0729.D08222.
```

| Field | Value |
|---|---|
| direction | debit |
| amount | 10.00 → 1000 |
| merchant | SOCHESCARE AIRTEL NETWORKS SELF CARE SOCHE (or till token SOCHESCARE) |
| balance | 45.23 (optional update) |
| external_ref | MP260728.0729.D08222 |
| type hint | till_payment |

#### Airtel Money — Withdrawal

```
You have withdrawn K200.00 from 20068466 FELIX MONDE. Bal is K55.23. TID: CO260727.1954.D21146.
```

| Field | Value |
|---|---|
| direction | debit |
| amount | 20000 |
| merchant | FELIX MONDE (agent) |
| external_ref | CO260727.1954.D21146 |
| type hint | withdrawal |

#### Airtel Money — Money sent

```
Money sent to Sibeso Nyumbu on 979142832.Amount K205.00. Your bal is K260.23.TID: PP260727.1512.M73944
```

| Field | Value |
|---|---|
| direction | debit |
| amount | 20500 |
| merchant | Sibeso Nyumbu |
| phone | 979142832 |
| external_ref | PP260727.1512.M73944 |
| type hint | send |

#### Airtel Money — Payment (numeric till)

```
Payment of K1.00 Till Number 300770 GOODFELLOW DIGITAL LIMITED. Airtel Money bal is K466.53. TID : MP260727.1129.Y34799.
```

| Field | Value |
|---|---|
| direction | debit |
| amount | 100 |
| merchant | GOODFELLOW DIGITAL LIMITED |
| till | 300770 |
| external_ref | MP260727.1129.Y34799 |

#### Airtel Money — PAID + charge + date + link

```
PAID K600.00 to GLOBAL PAY COLLECTIONS Charge K0.00, TID XX260726.1524.M81597. Bal K601.35 Date: 26-July-2026 15:24. https://bit.ly/3ZgpiNw
```

| Field | Value |
|---|---|
| direction | debit |
| amount | 60000 |
| merchant | GLOBAL PAY COLLECTIONS |
| charge | 0 (ignore if zero) |
| external_ref | XX260726.1524.M81597 |
| transacted_at | 2026-07-26T15:24:00 (local → store UTC) |

#### Airtel Money — Received (K shorthand)

```
You have received K300 from CHISOMO MUTALE. Txn. ID: CI260726.1522.A37452. Reason: Mobile Money Transfer.
```

| Field | Value |
|---|---|
| direction | credit |
| amount | 30000 |
| merchant | CHISOMO MUTALE |
| external_ref | CI260726.1522.A37452 |
| note | Parser must accept `K` and `ZMW` |

#### Airtel Money — Money received (settlement)

```
Money received K1350.00 from 0245970 NFS SETTLEMENT ACCOUNT. Dial *115# to check balance. Deposits are free. TID: CI260726.1451.D36552
```

| Field | Value |
|---|---|
| direction | credit |
| amount | 135000 |
| merchant | NFS SETTLEMENT ACCOUNT |
| external_ref | CI260726.1451.D36552 |

#### Standard Chartered — Bank → Airtel transfer

```
Dear Client, transaction of K300.00 to Airtel has been processed successfully, ref. ZM2607260050941958 For any queries contact us on  5247
```

| Field | Value |
|---|---|
| direction | debit (from bank perspective) |
| amount | 30000 |
| merchant / counterparty | Airtel |
| external_ref | ZM2607260050941958 |
| account | StanChart account (when created) |
| **Gap** | Need more StanChart templates (POS, ATM, transfer in, failed) |

### 8.3 Parser architecture

```
ParserRegistry
  ├── register(ParserProvider)
  ├── findBySender(address) → List<ParserProvider>
  ├── parse(rawCapture) → ParseResult
  └── providers: [AirtelMoneyParser, StanChartParser]

ParserProvider
  key: String
  senderIds: Set<String>
  canParse(RawCapture): bool
  parse(RawCapture): ParseResult

ParseResult
  success → TransactionDraft + confidence
  failure → error reason (raw stays failed)
```

**Rules:**

- Deterministic regex / token rules first.
- One provider package / file per bank; adding a third provider = new class + register — no engine rewrite.
- Prefer `external_ref` (TID) as `idempotency_key` when present.
- Strip trailing marketing links from body before merchant extraction when needed.
- Normalize amounts: `K1,350.00`, `K1350.00`, `K300`, `K 300.00`.
- If parse fails → `raw_captures.parse_status=failed` + appear in Review Inbox.

### 8.4 Suggested Airtel rule families (implementation hints)

| Family | Triggers (examples) | Direction |
|---|---|---|
| `payment_till` | `Payment of K… Till Number` | debit |
| `paid_to` | `PAID K… to` | debit |
| `withdrawn` | `You have withdrawn` | debit |
| `money_sent` | `Money sent to` | debit |
| `received_k` | `You have received K` / `received ZMW` | credit |
| `money_received` | `Money received ZMW` | credit |

TID patterns observed: `MP`, `CO`, `PP`, `XX`, `CI` + date-time-like suffix.

### 8.5 StanChart rule families (initial)

| Family | Triggers | Direction |
|---|---|---|
| `txn_to_airtel` | `Dear Client, transaction of K… to Airtel` | debit |

**Flag for later:** collect 5–10 more StanChart samples (POS, ATM, incoming, card, failed).

### 8.6 Cross-provider duplicate risk

Airtel receive + StanChart “to Airtel” may represent **two sides of one real-world movement** (bank → MoMo). Phase 1:

- Treat as **separate transactions on different accounts** (correct double-entry across accounts), OR
- Flag same amount + close time window across accounts as `duplicate_suspect` for human review.

**Decision for Phase 1:** Keep both if accounts differ; surface cross-account same-amount same-window as optional review hint — do not auto-merge.

---

## 9. Voice Entry Pipeline

```
[Quick-add mic / shortcut]
    → record WAV (16 kHz mono) to temp file
    → Whisper on-device (isolate) → transcript
    → PII strip (long digit sequences / account-like tokens)
    → if online: AiProvider.extractTransaction(transcript)
         JSON: { amount, currency, category_guess, merchant_guess,
                 payment_method, date, confidence? }
    → if offline: save raw voice capture + transcript; status needs_review
         (or pending_extraction)
    → ConfidenceScorer
         ≥ 0.85 AND amount present AND category present → auto-save confirmed
         else → needs_review inbox
```

### Defaults

- `currency`: `ZMW`
- `payment_method`: `cash` if unspecified
- `date`: today if unspecified
- Language: English

### Packages (evaluate at implementation)

- `whisper_ggml` or maintained whisper.cpp Flutter binding
- Models: `tiny` (speed) / `base` (accuracy) — download on Wi-Fi, show progress

### Not in Phase 1

- Live streaming STT
- Non-English models
- Offline LLM extraction

---

## 10. Review Inbox & Duplicate Detection

### 10.1 Review Inbox (most important screen)

Single screen listing everything needing a human glance:

| Source | Reason |
|---|---|
| Failed SMS parse | `raw_captures.parse_status=failed` |
| Low-confidence voice | `confidence < 0.85` |
| Missing amount or category | incomplete draft |
| Uncategorized manual (optional policy) | category null |
| Duplicate suspect | fuzzy match flagged |

Actions: assign category, edit amount/merchant/date, confirm, merge/dismiss duplicate, mark ignore (for non-financial SMS from same sender), re-parse.

### 10.2 Duplicate detection

Before insert from any source:

1. **Hard dedupe:** same `idempotency_key` / same `external_ref` / same `content_hash` → skip insert, link to existing.
2. **Fuzzy dedupe:** same `amount_minor` + normalized merchant similarity + `transacted_at` within window (e.g. **±30 minutes**) → `duplicate_suspect` → inbox.

Do not silently drop fuzzy matches — human decides.

---

## 11. Budgets & Reports

### Budgets

- Dedicated screen: create / edit / delete
- Monthly limit per category (`period = YYYY-MM`)
- New month: **carry previous amounts as editable defaults**
- Live over/under vs sum of confirmed debits in category for period

### Reports (Phase 1)

- Monthly spend by category (local SQL aggregation)
- No LLM narration in Phase 1

---

## 12. AI Provider Abstraction

```dart
abstract class AiProvider {
  Future<TransactionExtraction> extractTransaction({
    required String transcript,
    required String locale, // 'en'
  });

  // Phase 2+:
  // Future<CategoryGuess> categorizeMerchant(...);
  // Future<String> narrate(...);
}

class AnthropicClaudeProvider implements AiProvider { ... }
```

- Feature code depends on `AiProvider` only.
- Strip account numbers / unnecessary PII before send.
- Confirm Anthropic data-retention policy before sending real transaction text (checklist item).
- Network required; surface clear error + leave item in inbox if call fails.

### Extraction JSON contract

```json
{
  "amount": 50.0,
  "currency": "ZMW",
  "category_guess": "Transport",
  "merchant_guess": "Taxi",
  "payment_method": "cash",
  "date": "2026-07-28",
  "confidence": 0.9
}
```

Map `amount` → `amount_minor` in domain layer (never trust float past the boundary — round carefully to ngwee).

---

## 13. Security

| Requirement | Phase 1 plan |
|---|---|
| SQLCipher on local DB | **Day one** with Drift bootstrap |
| Android Keystore for secrets | DB passphrase + any stored API key / tokens |
| No plaintext API keys in source / SharedPreferences | Enforced |
| Client-side encryption of backups | When backup feature exists (not Phase 1 core) |
| Biometric/PIN app lock | **Can wait** — Phase 1 late or 1.5 (flagged) |
| Screenshot-blocking on sensitive screens | **Can wait** — same |
| Strip PII before LLM | Required for voice extraction |
| Confirm LLM retention policy | Checklist before real data |

---

## 14. Sync & Auth (Deferred)

**Phase 1 local-only is intentional** (D05, D37).

When ready (after DoD local week):

1. Supabase project + Postgres schema mirroring local tables with `user_id`
2. RLS: user can only read/write own rows — **build & test before inviting second synced user**
3. Supabase Auth
4. PowerSync (preferred) with LWW on `updated_at`
5. Encryption alignment: prefer choosing encryption approach at bootstrap that PowerSync supports (sqlite3mc) to avoid migration — **revisit at sync kickoff**

Until then: generate stable local `user_id` UUID at first launch and store in Keystore-backed storage.

---

## 15. Phase Breakdown & Build Order

### Phase 0 — Foundation (before domain UI)

1. Rename app / package ID (decision pending — see open items).
2. Strip or inert-ize unrelated schema (`providers`/`plans`) and Firebase usage paths as needed (“ignore for now” = do not build on Firebase).
3. Replace `local_data`/sqflite with **Drift + SQLCipher** bootstrap.
4. Repository interfaces: accounts, categories, transactions, raw_captures.
5. Seed categories + default Airtel Money account.
6. Add `AiProvider` interface (stub impl OK).
7. Android SMS platform channel skeleton + permission wiring.
8. (Optional) NotificationListener skeleton behind flag.

### Phase 1a — Manual baseline

1. Manual transaction entry UI (amount, direction, category, account, merchant, date).
2. Transaction list (local only).
3. Prove offline CRUD works end-to-end.

### Phase 1b — SMS capture + parsers + inbox

1. Inbox backfill + live SMS events → `raw_captures`.
2. `AirtelMoneyParser` covering all families in §8.
3. `StanChartParser` for known template; failed → inbox.
4. **Review Inbox** screen (failed parses + needs_review).
5. Unit tests with exact sample corpus strings (no device required).

### Phase 1c — Trust layer

1. Hard + fuzzy duplicate detection.
2. Category assign/edit from inbox and transaction detail.
3. Idempotency via TID / content_hash.

### Phase 1d — Voice

1. Quick-add recording UI.
2. On-device Whisper transcription.
3. Claude extraction when online; inbox when offline/fail/low confidence.
4. Threshold **0.85** routing.
5. Collect ≥20 real EN recordings for verification (DoD).

### Phase 1e — Budgets + reports

1. Budget CRUD + monthly carry-over defaults.
2. Live over/under.
3. Monthly spend-by-category report.

### Phase 1f — Hardening (still single-device)

1. Encryption verification (DB file not readable as plaintext).
2. Capture success metrics (parsed vs failed %).
3. One full week daily use without data-trust incidents.

### Phase 1g — Sync (only after 1a–1f)

1. Supabase schema + RLS.
2. Auth.
3. PowerSync connect.
4. Two-device offline→online test (when multi-device becomes needed).

**Explicit reorder vs original brief:** encryption moves to Phase 0; categories with schema; review inbox with SMS (not after voice); sync last.

---

## 16. Definition of Done — Phase 1

Before Phase 2:

- [ ] ≥ **80%** of real SMS transactions auto-captured with zero manual entry (Airtel + StanChart mix as used daily)
- [ ] **Never** silently drop a capture; failures appear in Review Inbox
- [ ] Voice entry extracts correctly on clear EN utterances; verified on **≥20** personal recordings
- [ ] Auto-save only when confidence ≥ **0.85** and required fields present
- [ ] App usable fully offline for add / budgets / reports
- [ ] SQLCipher enabled; no secrets in plaintext prefs/source
- [ ] One full week real daily use with **no** data-trust incident (missing / duplicated / miscategorized needing detective work)
- [ ] Sync across two devices — **waived for Phase 1** given single-device decision; re-enable when Phase 1g starts

---

## 17. Risks & Mitigations

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| 1 | StanChart format coverage thin | Missed bank txns | Collect more samples; failed → inbox |
| 2 | Airtel template drift | Parse failures | Version parsers; never drop raw; fix rules from inbox |
| 3 | SMS permission denied by friend | No auto-capture | Clear onboarding; manual + voice fallback |
| 4 | False auto-saves | Wrong books | 0.85 threshold; prefer inbox when fields missing |
| 5 | Duplicate SMS delivery / re-backfill | Inflated spend | TID idempotency + content_hash |
| 6 | Bank→MoMo double representation | Confusion | Cross-account hint; no auto-merge Phase 1 |
| 7 | Whisper size/latency | Friction | `tiny` default; Wi-Fi model download |
| 8 | Claude key abuse if in APK | Cost | Private sideload only; move to proxy before wider share |
| 9 | SQLCipher + future PowerSync mismatch | Migration pain | Revisit encryption choice at sync kickoff |
| 10 | Android OEM SMS quirks | Missed broadcasts | Launch-time inbox diff as source of truth |
| 11 | Float/display bugs | Wrong totals | Integer `amount_minor` everywhere |
| 12 | Ignoring Firebase leaves dead code | Confusion | Phase 0: document inert paths; strip when touching auth |

---

## 18. Explicit Non-Goals

- Custom CRDT / OT sync
- Gamification beyond future financial health score
- Wearable / browser extension / desktop companion
- Play Store release in Phase 1
- Becoming default SMS app
- ElectricSQL
- Agents
- Multi-currency
- Non-English voice
- Phase 2+ intelligence (alias LLM categorization, health score, digests, NL query, OCR, etc.)

---

## 19. Open Items (Can Wait)

| Item | Needed for | Notes |
|---|---|---|
| Final app name / applicationId | Phase 0 rename | Can keep template ID briefly |
| More StanChart SMS samples (5–10) | Parser completeness / 80% DoD | **Important but can arrive during 1b** |
| Confirm min SDK with friends’ devices | Phase 0 gradle | Default API 26 |
| Anthropic billing account + key handling (proxy vs client) | Voice 1d | Sideload client key OK short-term |
| Biometric lock / screenshot flag timing | Security polish | Phase 1 late or 1.5 |
| PowerSync Cloud vs self-host | Phase 1g | Not blocking |
| Firebase: strip vs leave | Phase 0 cleanup depth | Ignore functionally for now |
| Exact fuzzy merchant similarity algorithm | Dedupe 1c | Start with normalized string equality + amount + time window |
| Account mapping UX for StanChart vs Airtel | Multi-account expansion | Seed second account when first StanChart SMS parsed |
| NotificationListener enable by default? | Hybrid depth | Default **off** until SMS proven; turn on if gaps found |

---

## 20. Phase 2–4 Roadmap (Reference Only)

### Phase 2 — Intelligence

- Merchant-alias table + correction feedback loop
- LLM categorization only for unseen / low-confidence merchants
- Deterministic recurring detection
- Savings goals + forecast dates
- Trends, overspending alerts
- Financial health score (explainable components)
- Daily/weekly digest notifications

### Phase 3 — Conversational

- NL query over history
- AI coach summaries
- Receipt OCR via vision LLM
- Unusual txn detection
- PDF / Excel export

### Phase 4 — Expanded surface

- Multi-account net worth time series
- Investments (manual)
- Bill detection / reminders
- Subscription audit
- Zambia tax-category tagging + year-end export
- Email parsing
- Calendar integration

---

## 21. Appendix

### 21.1 Original architecture non-negotiables (preserved)

- Offline-first
- Local SQLite source of truth
- Drift + SQLCipher
- Supabase + multi-tenant RLS when sync lands
- LWW conflicts
- AI provider abstraction
- Claude via Anthropic API
- Keystore for secrets

### 21.2 Refined Phase 1 sequence (authoritative)

1. Encrypted Drift schema + seeds  
2. Manual entry  
3. SMS bridge + raw captures  
4. Airtel + StanChart parsers + **Review Inbox**  
5. Duplicate detection  
6. Voice (Whisper → Claude online → 0.85)  
7. Budgets  
8. Reports  
9. (Later) Supabase Auth + PowerSync  

### 21.3 Sample corpus JSON (raw)

```json
[
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "Payment of K10.00 Till Number SOCHESCARE AIRTEL NETWORKS SELF CARE SOCHE. Airtel Money bal is K45.23. TID : MP260728.0729.D08222."
  },
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "You have withdrawn K200.00 from 20068466 FELIX MONDE. Bal is K55.23. TID: CO260727.1954.D21146."
  },
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "Money sent to Sibeso Nyumbu on 979142832.Amount K205.00. Your bal is K260.23.TID: PP260727.1512.M73944"
  },
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "Payment of K1.00 Till Number 300770 GOODFELLOW DIGITAL LIMITED. Airtel Money bal is K466.53. TID : MP260727.1129.Y34799."
  },
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "PAID K600.00 to GLOBAL PAY COLLECTIONS Charge K0.00, TID XX260726.1524.M81597. Bal K601.35 Date: 26-July-2026 15:24. https://bit.ly/3ZgpiNw"
  },
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "You have received K300 from CHISOMO MUTALE. Txn. ID: CI260726.1522.A37452. Reason: Mobile Money Transfer."
  },
  {
    "sender_candidates": ["AirtelMoney", "24783566639"],
    "body": "Money received K1350.00 from 0245970 NFS SETTLEMENT ACCOUNT. Dial *115# to check balance. Deposits are free. TID: CI260726.1451.D36552"
  },
  {
    "sender_candidates": ["StanChartZM", "78262427896"],
    "body": "Dear Client, transaction of K300.00 to Airtel has been processed successfully, ref. ZM2607260050941958 For any queries contact us on  5247"
  }
]
```

### 21.4 Document history

| Date | Change |
|---|---|
| 2026-07-28 | Initial comprehensive plan from grounded brainstorm + user decisions, SMS corpus, and sender IDs |

---

*End of plan. Implementation should not start until this document is accepted; updates land in the Decisions Log (§3) and Open Items (§19).*
