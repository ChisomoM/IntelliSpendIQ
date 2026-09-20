import 'dart:convert';

import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/domain/models/reminder_settings.dart';

/// Persists the expense-reminder configuration as one JSON blob in the
/// existing key-value `settings` table, so it needs no schema change.
class ReminderSettingsRepository {
  ReminderSettingsRepository(this._settings);

  final SettingsRepository _settings;

  static const settingsKey = 'reminder_settings_json';

  /// Day a reminder was last snoozed (`YYYY-MM-DD`, local), so a
  /// snoozed reminder can be re-offered at most once per day.
  static const lastSnoozeDateKey = 'reminder_last_snooze_date';

  Future<ReminderSettings> load() async {
    final raw = await _settings.get(settingsKey);
    if (raw == null) return ReminderSettings.defaults();
    try {
      return ReminderSettings.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on FormatException {
      return ReminderSettings.defaults();
    }
  }

  Future<void> save(ReminderSettings settings) =>
      _settings.set(settingsKey, jsonEncode(settings.toJson()));

  Future<String?> lastSnoozeDate() => _settings.get(lastSnoozeDateKey);

  Future<void> setLastSnoozeDate(String localDateKey) =>
      _settings.set(lastSnoozeDateKey, localDateKey);
}
