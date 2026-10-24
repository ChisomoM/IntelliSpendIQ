# Capturing and nudging while the app is closed

The goal: when a payment SMS arrives and the app cannot categorize it, ask
"What was this?" right away, even if the app is not running, with one-tap
category buttons on the notification.

## How it works

```
SMS arrives
  └─ SmsReceiver.kt
       ├─ app running (Dart listening)  → live event stream, as before
       └─ app closed
            ├─ sender not recognized    → ignored (KnownSenders.kt)
            └─ sender recognized        → BackgroundCapture.kt
                 └─ headless FlutterEngine runs captureBackgroundMain()
                      1. CaptureCore.open(): encrypted DB, no Firebase
                      2. same CaptureService.ingest() as the app
                      3. BatchingCaptureNudger posts the notification
                      4. native tears the engine down
```

Tapping a category button runs `nudgeActionBackground` in the notification
plugin's own isolate: it opens the DB, categorizes the transaction, teaches
the merchant rule (so the next payment there is categorized on arrival) and
the notification clears. The app is never opened.

## Reliability

This is best effort, and nothing depends on it:

- The launch-time inbox backfill is still the source of truth. If the
  background run times out (8s), is killed by the phone's battery manager, or
  fails, the SMS is still in the inbox and is ingested on the next open.
- Ingest is idempotent (SMS id and a 10-minute content hash), so the live
  path, the background path and the backfill can all see the same message.
- A nudge is skipped, never queued, when it is off, in quiet hours
  (10pm to 7am), for money received, for anything the categorizer already
  placed, or for a capture more than two hours old.

## Pieces

| Where | What |
|---|---|
| `lib/domain/services/capture_core.dart` | Wiring shared by the app and the background entrypoint |
| `lib/background/capture_background.dart` | Headless entrypoint and per-message handler |
| `lib/background/nudge_actions.dart` | Category button handler |
| `lib/domain/services/capture_nudger.dart` | Policy, batching, message building |
| `android/.../SmsReceiver.kt` | Chooses live path or background path |
| `android/.../BackgroundCapture.kt` | Starts and stops the headless engine |
| `android/.../KnownSenders.kt` | Native cache of recognized sender IDs |

## Two engines, one database

The background engine opens its own connection to the same SQLCipher file.
`connection.dart` sets WAL and a 5s `busy_timeout` so the writers take turns.
Drift cannot see writes made through another connection, so
`AppDatabase.refreshAfterExternalWrites()` re-runs open queries whenever the
app returns to the foreground.

## Known limits

- A schema migration could in theory run in the background engine if an SMS
  arrives after an app update but before the first launch.
- A category button tapped while the app is on screen updates the data, but
  the screen refreshes on the next resume rather than instantly.
- The secondary notification-listener channel does not start the background
  engine (it would wake for every notification from every app).
- Phones with aggressive battery managers (autostart, "protected apps") may
  still block the receiver. Settings → Reminders links to the system screen.

## Testing on a device

Dart tests cover the policy, batching, handler and button logic. The Kotlin
and engine path needs a device or emulator:

1. Turn on **Settings → Reminders → Ask me what new spending was** and allow
   notifications. Open the app once so the known senders are published.
2. Force-stop the app: `adb shell am force-stop com.intellispendiq.app`
   (use the flavor's application id if it differs).
3. Send a message from a recognized sender, e.g. on an emulator:
   `adb emu sms send AirtelMoney "You have withdrawn K200.00 from 20068466 FELIX MONDE. Bal is K55.23. TID: CO260727.1954.D21146."`
4. Expect a "What was this?" notification within a few seconds, with up to
   three category buttons once there is some categorized history.
5. Tap a button. The notification clears; open the app and the transaction
   is categorized.
6. Repeat with the app force-stopped and an unrecognized sender: nothing
   should happen, and no raw capture should be stored.
7. `adb logcat -s BackgroundCapture capture_background nudge_actions` shows
   timeouts and Dart failures.
