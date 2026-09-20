part of 'reminder_settings_cubit.dart';

enum ReminderSettingsStatus { initial, loaded, saving }

class ReminderSettingsState extends Equatable {
  const ReminderSettingsState({
    this.status = ReminderSettingsStatus.initial,
    ReminderSettings? settings,
  }) : _settings = settings;

  final ReminderSettingsStatus status;
  final ReminderSettings? _settings;

  ReminderSettings get settings => _settings ?? _defaults;
  static final _defaults = ReminderSettings.defaults();

  ReminderSettingsState copyWith({
    ReminderSettingsStatus? status,
    ReminderSettings? settings,
  }) => ReminderSettingsState(
    status: status ?? this.status,
    settings: settings ?? _settings,
  );

  @override
  List<Object?> get props => [status, _settings];
}
