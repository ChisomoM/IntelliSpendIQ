import 'package:equatable/equatable.dart';

/// A wall-clock time of day, minute precision. Kept separate from
/// `TimeOfDay` so this model has no Flutter dependency.
class ReminderTimeOfDay extends Equatable {
  const ReminderTimeOfDay({required this.hour, required this.minute});

  final int hour;
  final int minute;

  static const defaultTime = ReminderTimeOfDay(hour: 20, minute: 0);

  Map<String, Object?> toJson() => {'hour': hour, 'minute': minute};

  static ReminderTimeOfDay? fromJson(Object? json) {
    if (json is! Map) return null;
    final hour = json['hour'];
    final minute = json['minute'];
    if (hour is! int || minute is! int) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return ReminderTimeOfDay(hour: hour, minute: minute);
  }

  @override
  List<Object?> get props => [hour, minute];
}

/// One weekday's slot: whether a reminder fires that day, and (only
/// when the settings are in "custom" mode) its own time.
class ReminderDaySettings extends Equatable {
  const ReminderDaySettings({required this.enabled, this.time});

  final bool enabled;

  /// Null when `ReminderSettings.sameTimeForAllDays` is true — the
  /// uniform time applies instead.
  final ReminderTimeOfDay? time;

  ReminderDaySettings copyWith({bool? enabled, ReminderTimeOfDay? time}) =>
      ReminderDaySettings(
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
      );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'time': time?.toJson(),
  };

  static ReminderDaySettings fromJson(Object? json) {
    if (json is! Map) return const ReminderDaySettings(enabled: true);
    return ReminderDaySettings(
      enabled: json['enabled'] == true,
      time: ReminderTimeOfDay.fromJson(json['time']),
    );
  }

  @override
  List<Object?> get props => [enabled, time];
}

/// The user's whole reminder configuration for the expense-logging
/// nudge. Persisted as one JSON blob (see `ReminderSettingsRepository`).
///
/// Each weekday can be toggled independently, and either shares one
/// time (`sameTimeForAllDays`) or carries its own (`days[weekday].time`).
/// Weekdays are keyed 1 (Monday) through 7 (Sunday), matching
/// `DateTime.weekday`.
class ReminderSettings extends Equatable {
  const ReminderSettings({
    required this.enabled,
    required this.sameTimeForAllDays,
    required this.uniformTime,
    required this.days,
  });

  final bool enabled;
  final bool sameTimeForAllDays;
  final ReminderTimeOfDay uniformTime;
  final Map<int, ReminderDaySettings> days;

  /// Off, every day enabled at a shared 8pm slot — the shape reminders
  /// take the first time a user turns them on.
  factory ReminderSettings.defaults() => ReminderSettings(
    enabled: false,
    sameTimeForAllDays: true,
    uniformTime: ReminderTimeOfDay.defaultTime,
    days: {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: const ReminderDaySettings(enabled: true),
    },
  );

  bool isEnabledFor(int weekday) =>
      enabled && (days[weekday]?.enabled ?? false);

  ReminderTimeOfDay timeFor(int weekday) =>
      sameTimeForAllDays ? uniformTime : (days[weekday]?.time ?? uniformTime);

  ReminderSettings copyWith({
    bool? enabled,
    bool? sameTimeForAllDays,
    ReminderTimeOfDay? uniformTime,
    Map<int, ReminderDaySettings>? days,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    sameTimeForAllDays: sameTimeForAllDays ?? this.sameTimeForAllDays,
    uniformTime: uniformTime ?? this.uniformTime,
    days: days ?? this.days,
  );

  ReminderSettings withDay(int weekday, ReminderDaySettings day) =>
      copyWith(days: {...days, weekday: day});

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'sameTimeForAllDays': sameTimeForAllDays,
    'uniformTime': uniformTime.toJson(),
    'days': {
      for (final entry in days.entries) '${entry.key}': entry.value.toJson(),
    },
  };

  static ReminderSettings fromJson(Map<String, Object?> json) {
    final defaults = ReminderSettings.defaults();
    final rawDays = json['days'];
    final days = <int, ReminderDaySettings>{...defaults.days};
    if (rawDays is Map) {
      for (final entry in rawDays.entries) {
        final weekday = int.tryParse('${entry.key}');
        if (weekday == null || weekday < 1 || weekday > 7) continue;
        days[weekday] = ReminderDaySettings.fromJson(entry.value);
      }
    }
    return ReminderSettings(
      enabled: json['enabled'] == true,
      sameTimeForAllDays: json['sameTimeForAllDays'] != false,
      uniformTime:
          ReminderTimeOfDay.fromJson(json['uniformTime']) ??
          ReminderTimeOfDay.defaultTime,
      days: days,
    );
  }

  @override
  List<Object?> get props => [enabled, sameTimeForAllDays, uniformTime, days];
}
