import 'package:intellispendiq/data/db/app_database.dart';

/// Non-secret app state (backfill watermark, flags). Secrets belong in
/// the Keystore-backed secure store, never here.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const smsBackfillWatermarkKey = 'sms_backfill_watermark_ms';
  static const onboardingDoneKey = 'onboarding_done';
  static const notificationCaptureEnabledKey = 'notification_capture_enabled';

  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<int?> getInt(String key) async {
    final value = await get(key);
    return value == null ? null : int.tryParse(value);
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await get(key);
    return value == null ? defaultValue : value == 'true';
  }
}
