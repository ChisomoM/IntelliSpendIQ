import 'package:intellispendiq/data/repositories/nudge_settings_repository.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/domain/services/reminder_scheduler.dart';

/// Asks for the notification permission once, the first time the app is
/// open with nudging on, instead of waiting for the user to find and flip
/// a switch.
///
/// Android shows its own prompt only while the permission is still
/// undecided, so asking again after a "no" does nothing. That case is
/// handled in the Reminders settings card, which links to system settings.
class NudgePermission {
  NudgePermission({
    required SettingsRepository settings,
    required NudgeSettingsRepository nudgeSettings,
    required ReminderService reminders,
  }) : _settings = settings,
       _nudgeSettings = nudgeSettings,
       _reminders = reminders;

  static const askedKey = 'nudge_permission_asked';

  final SettingsRepository _settings;
  final NudgeSettingsRepository _nudgeSettings;
  final ReminderService _reminders;

  /// Shows the system prompt if nudging is on, notifications are not
  /// already allowed, and it has never been shown before. Returns true
  /// when the prompt was shown.
  Future<bool> requestOnce() async {
    if (await _settings.getBool(askedKey)) return false;
    if (!(await _nudgeSettings.load()).enabled) return false;
    if (await _reminders.areNotificationsEnabled()) {
      // Already allowed (an earlier version, or the reminders switch).
      await _settings.set(askedKey, 'true');
      return false;
    }
    // Recorded first: a prompt that crashes or is dismissed must not
    // come back on every launch.
    await _settings.set(askedKey, 'true');
    await _reminders.requestPermission();
    return true;
  }
}
