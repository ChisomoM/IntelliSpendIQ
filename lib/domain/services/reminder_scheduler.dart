import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intellispendiq/core/deep_link.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/reminder_settings_repository.dart';
import 'package:intellispendiq/domain/models/reminder_settings.dart';
import 'package:intellispendiq/platform/deep_link_source.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// What the rest of the app needs from the reminder system, kept
/// separate from [ReminderScheduler] so tests can swap in a no-op
/// implementation instead of touching the notification/timezone
/// platform channels.
abstract interface class ReminderService implements DeepLinkSource {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> reschedule(ReminderSettings settings);
  Future<void> onActivityLogged();
  Future<void> cancelAll();
  Future<void> dispose();
}

/// Schedules the local, offline "log your expenses" nudge: one
/// recurring notification per enabled weekday, snoozing, and
/// cancelling today's occurrence once the user has actually logged
/// something.
///
/// Everything here is on-device — no server, no push token. Android
/// and iOS both keep repeating local notifications armed across app
/// restarts on their own; this class only has to (re)compute the next
/// fire time whenever the schedule, the timezone, or the user's
/// activity changes.
///
/// Implements [DeepLinkSource] so a notification tap — whether it
/// launched the app cold or arrived while it was already running —
/// flows through the same "open the add-transaction screen" path as
/// any other deep link, via `CompositeDeepLinkSource`.
class ReminderScheduler implements ReminderService {
  ReminderScheduler({
    required ReminderSettingsRepository settingsRepository,
    required Future<bool> Function() hasLoggedToday,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _settingsRepository = settingsRepository,
       _hasLoggedToday = hasLoggedToday,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final ReminderSettingsRepository _settingsRepository;
  final Future<bool> Function() _hasLoggedToday;
  final FlutterLocalNotificationsPlugin _plugin;
  final _tapController = StreamController<Uri>.broadcast();
  Uri? _pendingLaunchUri;
  var _initialized = false;

  static const _channelId = 'expense_reminders';
  static const _channelName = 'Expense reminders';
  static const _channelDescription =
      'Gentle nudges to log expenses you have not tracked yet';
  static const _reminderCategoryId = 'reminder';
  static const _title = 'IntelliSpendIQ';
  static const _body = "You haven't logged anything today — take a sec?";
  static const _snoozeBody = 'Still there? A quick log keeps today complete.';
  static const _snoozeActionId = 'snooze_1h';
  static const _logNowActionId = 'log_now';
  static const _snoozeNotificationId = 999;
  static const _snoozeDuration = Duration(hours: 1);
  static const _addTransactionUri = '${DeepLink.scheme}://add';

  static int _recurringId(int weekday) => 100 + weekday;

  /// Sets up the plugin, the timezone database, and the notification
  /// channel. Safe to call once at startup, before the schedule is
  /// (re)applied. Also picks up a snooze tapped while the app was
  /// fully closed, since that arrives as launch details rather than
  /// through [links].
  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()),
      );
    } on Exception {
      // Device reported a zone `timezone` doesn't recognise — falling
      // back to its default beats failing startup over it.
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      await _route(launchResponse, isColdStart: true);
    }
  }

  /// Requests the OS permission needed to show notifications at all
  /// (Android 13+, iOS). Call this only when the user turns reminders
  /// on, not at first launch, so the prompt has context.
  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Applies [settings]: schedules or cancels each weekday's recurring
  /// notification. Call after any settings change, and on app resume
  /// so a device timezone change gets picked up promptly.
  @override
  Future<void> reschedule(ReminderSettings settings) async {
    final loggedToday = settings.enabled && await _hasLoggedToday();
    final todayWeekday = DateTime.now().weekday;
    for (var weekday = 1; weekday <= 7; weekday++) {
      final id = _recurringId(weekday);
      if (!settings.isEnabledFor(weekday)) {
        await _plugin.cancel(id);
        continue;
      }
      await _plugin.zonedSchedule(
        id,
        _title,
        _body,
        _nextInstance(
          weekday,
          settings.timeFor(weekday),
          skipToday: weekday == todayWeekday && loggedToday,
        ),
        _recurringDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Call right after a transaction is logged. Cancels any pending
  /// snooze and pushes today's recurring slot out to next week,
  /// without disturbing the weekly cadence for the days after.
  @override
  Future<void> onActivityLogged() async {
    await _plugin.cancel(_snoozeNotificationId);
    final settings = await _settingsRepository.load();
    final weekday = DateTime.now().weekday;
    if (!settings.isEnabledFor(weekday)) return;
    await _plugin.zonedSchedule(
      _recurringId(weekday),
      _title,
      _body,
      _nextInstance(weekday, settings.timeFor(weekday), skipToday: true),
      _recurringDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> cancelAll() async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_recurringId(weekday));
    }
    await _plugin.cancel(_snoozeNotificationId);
  }

  void _handleResponse(NotificationResponse response) {
    unawaited(_route(response, isColdStart: false));
  }

  Future<void> _route(
    NotificationResponse response, {
    required bool isColdStart,
  }) async {
    if (response.actionId == _snoozeActionId) {
      await _snoozeOnce();
      return;
    }
    final uri = Uri.parse(_addTransactionUri);
    if (isColdStart) {
      _pendingLaunchUri = uri;
    } else {
      _tapController.add(uri);
    }
  }

  /// Reschedules a one-off follow-up an hour out, at most once per
  /// local day — the second offer of the day drops the snooze action
  /// entirely, so this can never chain into a drip of notifications.
  Future<void> _snoozeOnce() async {
    final todayKey = Iso.localDateKey(DateTime.now());
    final lastSnoozeDate = await _settingsRepository.lastSnoozeDate();
    final alreadySnoozedToday = lastSnoozeDate == todayKey;
    await _settingsRepository.setLastSnoozeDate(todayKey);

    await _plugin.zonedSchedule(
      _snoozeNotificationId,
      _title,
      _snoozeBody,
      tz.TZDateTime.now(tz.local).add(_snoozeDuration),
      _snoozeDetails(offerAnotherSnooze: !alreadySnoozedToday),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  NotificationDetails _recurringDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      actions: [
        AndroidNotificationAction(
          _logNowActionId,
          'Log now',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _snoozeActionId,
          'Remind me in 1h',
          showsUserInterface: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: _reminderCategoryId),
  );

  NotificationDetails _snoozeDetails({required bool offerAnotherSnooze}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          actions: [
            const AndroidNotificationAction(
              _logNowActionId,
              'Log now',
              showsUserInterface: true,
            ),
            if (offerAnotherSnooze)
              const AndroidNotificationAction(
                _snoozeActionId,
                'Remind me in 1h',
                showsUserInterface: true,
              ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _reminderCategoryId,
        ),
      );

  tz.TZDateTime _nextInstance(
    int weekday,
    ReminderTimeOfDay time, {
    required bool skipToday,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduled.weekday != weekday ||
        !scheduled.isAfter(now) ||
        (skipToday && _isSameDate(scheduled, now))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<Uri?> initialLink() async {
    final uri = _pendingLaunchUri;
    _pendingLaunchUri = null;
    return uri;
  }

  @override
  Stream<Uri> links() => _tapController.stream;

  @override
  Future<void> dispose() => _tapController.close();
}
