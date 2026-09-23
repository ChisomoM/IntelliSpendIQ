import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/reminder_settings_repository.dart';
import 'package:intellispendiq/domain/models/reminder_settings.dart';
import 'package:intellispendiq/domain/services/reminder_scheduler.dart';

part 'reminder_settings_state.dart';

/// Edits the expense-reminder schedule and keeps the OS notifications
/// in sync with every change — each setter here both persists and
/// reschedules, so the settings screen never needs a separate "save".
class ReminderSettingsCubit extends Cubit<ReminderSettingsState> {
  ReminderSettingsCubit(this._repository, this._scheduler)
    : super(const ReminderSettingsState());

  final ReminderSettingsRepository _repository;
  final ReminderService _scheduler;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    final settings = await _repository.load();
    if (isClosed) return;
    emit(
      ReminderSettingsState(
        status: ReminderSettingsStatus.loaded,
        settings: settings,
      ),
    );
  }

  /// Turns reminders on or off. Turning on requests the OS notification
  /// permission first — if it's denied, the switch stays off rather
  /// than silently scheduling notifications that will never show.
  Future<void> setEnabled({required bool enabled}) async {
    if (enabled) {
      final granted = await _scheduler.requestPermission();
      if (!granted) return;
    }
    await _apply(state.settings.copyWith(enabled: enabled));
  }

  Future<void> setSameTimeForAllDays({required bool sameTime}) =>
      _apply(state.settings.copyWith(sameTimeForAllDays: sameTime));

  Future<void> setUniformTime(ReminderTimeOfDay time) =>
      _apply(state.settings.copyWith(uniformTime: time));

  Future<void> setDayEnabled(int weekday, {required bool enabled}) {
    final day = state.settings.days[weekday] ?? const ReminderDaySettings(enabled: true);
    return _apply(
      state.settings.withDay(weekday, day.copyWith(enabled: enabled)),
    );
  }

  Future<void> setDayTime(int weekday, ReminderTimeOfDay time) {
    final day = state.settings.days[weekday] ?? const ReminderDaySettings(enabled: true);
    return _apply(state.settings.withDay(weekday, day.copyWith(time: time)));
  }

  /// Persists first, then reschedules the OS notifications. The screen
  /// reflects the saved choice even if rescheduling itself throws —
  /// what's stored is the source of truth, and a plugin failure here
  /// must never leave the settings screen stuck showing the old value.
  Future<void> _apply(ReminderSettings settings) async {
    emit(state.copyWith(status: ReminderSettingsStatus.saving));
    await _repository.save(settings);
    try {
      await _scheduler.reschedule(settings);
    } on Exception {
      // Swallowed deliberately: the setting is already saved, and the
      // next reschedule (next edit, or app resume) will retry it.
    }
    if (isClosed) return;
    emit(
      ReminderSettingsState(
        status: ReminderSettingsStatus.loaded,
        settings: settings,
      ),
    );
  }
}
