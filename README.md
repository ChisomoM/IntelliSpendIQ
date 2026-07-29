# IntelliSpendIQ

AI-powered personal finance tracker for Zambia. Captures transactions from **SMS
alerts** and **voice** so there is no manual entry to forget, keeps everything in
an encrypted local database, and surfaces anything it could not read with
confidence for a quick human glance.

Android-first, offline-first, distributed as a sideloaded APK.

## Priorities

The order matters, and it drove most of the design decisions:

1. **Reliability of capture** — never silently drop a financial event.
2. **Low friction** — auto-save when confident; ask only when it matters.
3. **Privacy** — local-first, encrypted at rest, PII stripped before any LLM call.

## How capture works

```
SMS / voice → persist raw → parse → dedupe → route
                                              ├─ confident  → saved
                                              └─ uncertain  → Review Inbox
```

The raw message is written to `raw_captures` **before** anything tries to parse
it. If every downstream step fails, the original text is still on disk and shows
up in the Review Inbox. A capture is never dropped, only routed.

- **SMS parsing is deterministic** — regex and token rules per provider, no LLM.
  Airtel Money covers six message families; Standard Chartered covers outbound
  transfers so far. Anything unrecognized fails loudly into the inbox rather than
  being guessed at.
- **Voice uses an LLM** because free-form speech is where it earns its keep.
  Extraction runs through a strict tool schema, and an entry auto-saves only at
  confidence ≥ 0.85 with a known category. Everything else goes to the inbox.
- **Money is integer minor units** (ngwee) end to end. Amounts never touch a
  double except at the LLM boundary, where they are rounded immediately.

## Duplicate handling

Two layers, because the failure modes differ:

- **Hard** — a repeat of a provider reference (TID / bank ref) or the same raw
  content links to the existing transaction instead of inserting a second one.
  This is what makes re-running the inbox backfill safe.
- **Fuzzy** — same amount, same normalized merchant, within 30 minutes gets
  flagged as `duplicate_suspect` and shown in the inbox. It is never auto-merged
  or discarded: two ZMW 200 withdrawals from the same agent minutes apart is a
  real thing that happens.

## Project layout

```
lib/
  bootstrap.dart      flavour-aware startup: error hooks, BlocObserver, DB
  main_development.dart / main_staging.dart / main_production.dart
  app/
    view/app.dart     MultiRepositoryProvider + MaterialApp
    cubit/            app-wide: theme mode, pending deep link
    theme/            Material 3 theme
    app_services.dart composition root
    app_bloc_observer.dart
  core/               money, ids/hashing, time, PIN hashing, deep link parsing
  data/
    db/               Drift schema, SQLCipher connection
    repositories/     accounts, categories, transactions, raw captures,
                      budgets, app lock
    secure/           Keystore-backed passphrase, user id, API key, PIN verifier
  domain/
    parsers/          ParserRegistry + one file per provider
    services/         capture pipeline, dedupe, SMS sync
    voice/            transcription interface, voice pipeline
    ai/               AiProvider abstraction + Claude implementation
  splash/             shown while the encrypted DB opens
  auth/ home/ transactions/ review/ budgets/ reports/ voice/ settings/
                      one folder per feature, each cubit/ + view/ + widgets/
  platform/           Android capture bridge, biometrics, deep link source

android/app/src/main/kotlin/com/intellispendiq/app/
  MainActivity.kt              method + event channel wiring
  SmsInboxBridge.kt            content://sms/inbox reader
  SmsReceiver.kt               live SMS broadcast
  NotificationCaptureService.kt  secondary channel, off by default
```

## App lock

Optional PIN, with biometrics as a shortcut once a PIN exists. Off by default;
turn it on in Settings.

It is a **UI gate, not a crypto gate**, and that is deliberate. Deriving the
database key from the PIN would make the database unreadable while the app is
locked — but SMS capture writes to it from a broadcast receiver at any hour. A
lock that made the capture pipeline fail closed would break priority #1 on every
message that arrived while the phone was in a pocket. So the data at rest is
protected by SQLCipher plus the Keystore, and the lock protects the screen from
someone holding an already-unlocked phone. Different threats, both covered.

- The PIN is stored as a salted PBKDF2-HMAC-SHA256 verifier in the Keystore,
  never in plaintext, and compared in constant time.
- Five wrong attempts start a cooldown that doubles per further failure, capped
  at 15 minutes. A cancelled biometric prompt never burns an attempt.
- There is no "forgot PIN" reset, because there is no server that could verify
  who you are. Clearing app data is the honest recovery path.
- Re-locks after 30 seconds in the background — not instantly, because the
  biometric prompt itself pauses the activity.

`AuthRepository` is the interface the UI is written against; `AppLockRepository`
is today's only implementation. A Google OAuth provider can be added later by
satisfying the same interface, without touching a cubit or a view.

## Deep links

`intellispendiq://<section>` and `https://intellispendiq.app/<section>` both
resolve, covering the five tabs plus `add`, `voice`, and `transaction/<id>`.

Parsing is pure (`core/deep_link.dart`) and tested without a device. A link is
only *parked* by `DeepLinkCubit`; `HomeView` performs the navigation — and
because `HomeView` exists only after the lock is satisfied, a link that arrives
at the lock screen simply waits. The gating is a property of where the listener
lives, so there is no check to forget. Unrecognized links are dropped, not
parked.

Verified app links need `/.well-known/assetlinks.json` served from the host;
until then https links open in the browser.

## Security

- The database is **SQLCipher-encrypted from the first launch** — there is no
  unencrypted-to-encrypted migration to get wrong later.
- The passphrase is generated on first run and stored in Android Keystore via
  `flutter_secure_storage`. If it cannot be read, the app shows the failure
  instead of quietly opening an unencrypted database.
- Long digit runs are masked out of voice transcripts before they leave the
  device.
- The Anthropic API key lives in Keystore, never in source or shared
  preferences. Acceptable for a private sideload; move it behind a thin proxy
  before sharing the APK more widely.

## Adding a provider parser

1. Implement `ParserProvider` (key, sender IDs, `parse`).
2. Register it in `ParserRegistry`.
3. Add the real message text to `test/support/corpus.dart` and assert on it.

No changes to the pipeline are needed. Parsers return a `TransactionDraft` and
never touch the database or UI, so their tests run without a device.

## Running it

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift codegen
flutter test

# Three flavours, each with its own entrypoint and applicationId suffix
flutter run --flavor development -t lib/main_development.dart
flutter build apk --flavor production -t lib/main_production.dart --release
```

Release builds fall back to debug signing when no keystore is configured, so a
fresh clone can produce an installable APK. Configure `key.properties` (or the
`ANDROID_KEYSTORE_*` environment variables) before sharing builds.

On first launch the app seeds ten editable categories and one default Airtel
Money account, then asks for SMS permission and backfills the last 30 days from
known senders only — personal messages are never imported.

## Current state

Working: encrypted storage, SMS capture and parsing, review inbox, duplicate
detection, manual entry, budgets with carry-over, monthly reports, the voice
pipeline behind a typed quick-add, app lock with PIN and biometrics, deep
links, and light/dark/system theming.

Not yet wired: on-device Whisper transcription (the voice sheet takes typed text
through the same extraction and routing path), and sync. Sync is deliberately
deferred — the schema carries `user_id`, `updated_at`, and soft deletes on every
table so it can be added without a migration, but the local loop needs to earn
trust first.
