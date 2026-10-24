import 'dart:convert';

import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/domain/models/nudge_settings.dart';

/// Persists the categorize-nudge configuration as one JSON blob in the
/// existing key-value `settings` table, so it needs no schema change.
class NudgeSettingsRepository {
  NudgeSettingsRepository(this._settings);

  final SettingsRepository _settings;

  static const settingsKey = 'nudge_settings_json';

  Future<NudgeSettings> load() async {
    final raw = await _settings.get(settingsKey);
    if (raw == null) return const NudgeSettings();
    try {
      return NudgeSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return const NudgeSettings();
    }
  }

  Future<void> save(NudgeSettings settings) =>
      _settings.set(settingsKey, jsonEncode(settings.toJson()));
}
