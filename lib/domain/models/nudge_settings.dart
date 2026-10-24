import 'package:equatable/equatable.dart';

/// Whether, and when, a freshly captured transaction that nobody could
/// categorize should prompt the user to sort it straight away.
///
/// Off by default: the notification permission prompt belongs next to
/// the switch that asks for it, same as expense reminders.
class NudgeSettings extends Equatable {
  const NudgeSettings({
    this.enabled = false,
    this.quietStartHour = defaultQuietStartHour,
    this.quietEndHour = defaultQuietEndHour,
  });

  static const defaultQuietStartHour = 22;
  static const defaultQuietEndHour = 7;

  final bool enabled;

  /// Local hour (0-23) at which quiet hours begin. May be later than
  /// [quietEndHour], in which case the window wraps past midnight.
  final int quietStartHour;

  /// Local hour (0-23) at which quiet hours end.
  final int quietEndHour;

  /// True when [local] falls inside quiet hours. Equal start and end
  /// hours mean no quiet window at all.
  bool isQuiet(DateTime local) {
    if (quietStartHour == quietEndHour) return false;
    final hour = local.hour;
    if (quietStartHour < quietEndHour) {
      return hour >= quietStartHour && hour < quietEndHour;
    }
    return hour >= quietStartHour || hour < quietEndHour;
  }

  NudgeSettings copyWith({
    bool? enabled,
    int? quietStartHour,
    int? quietEndHour,
  }) => NudgeSettings(
    enabled: enabled ?? this.enabled,
    quietStartHour: quietStartHour ?? this.quietStartHour,
    quietEndHour: quietEndHour ?? this.quietEndHour,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'quietStartHour': quietStartHour,
    'quietEndHour': quietEndHour,
  };

  static NudgeSettings fromJson(Map<String, Object?> json) {
    int hourOr(Object? value, int fallback) =>
        value is int && value >= 0 && value <= 23 ? value : fallback;
    return NudgeSettings(
      enabled: json['enabled'] == true,
      quietStartHour: hourOr(json['quietStartHour'], defaultQuietStartHour),
      quietEndHour: hourOr(json['quietEndHour'], defaultQuietEndHour),
    );
  }

  @override
  List<Object?> get props => [enabled, quietStartHour, quietEndHour];
}
