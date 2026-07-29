import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';

/// Light / dark / follow-system, persisted across launches.
///
/// The state is a bare [ThemeMode] rather than a wrapper class: there
/// is exactly one value to track, and [ThemeMode] already compares by
/// identity, so a state object would add nothing.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._settings) : super(ThemeMode.system);

  final SettingsRepository _settings;

  static const settingsKey = 'theme_mode';

  /// Reads the stored preference. An unrecognised or missing value
  /// falls back to following the system.
  Future<void> load() async {
    final stored = await _settings.get(settingsKey);
    emit(_parse(stored));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    await _settings.set(settingsKey, mode.name);
  }

  void loadUnawaited() => unawaited(load());

  void setThemeModeUnawaited(ThemeMode mode) => unawaited(setThemeMode(mode));

  static ThemeMode _parse(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return ThemeMode.system;
  }
}
