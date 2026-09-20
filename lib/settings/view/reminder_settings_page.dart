import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/reminder_settings_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/reminder_settings.dart';
import 'package:intellispendiq/domain/services/reminder_scheduler.dart';
import 'package:intellispendiq/settings/cubit/cubit.dart';

const _weekdayShort = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

const _weekdayFull = {
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

/// Configures the offline expense-logging nudge: on/off, which
/// weekdays, and whether every day shares one time or each has its
/// own. Nothing here needs a network — the schedule is applied to
/// local OS notifications as soon as it changes.
class ReminderSettingsPage extends StatelessWidget {
  const ReminderSettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ReminderSettingsPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReminderSettingsCubit(
        context.read<ReminderSettingsRepository>(),
        context.read<ReminderService>(),
      )..loadUnawaited(),
      child: const ReminderSettingsView(),
    );
  }
}

class ReminderSettingsView extends StatelessWidget {
  const ReminderSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: BlocBuilder<ReminderSettingsCubit, ReminderSettingsState>(
        builder: (context, state) {
          final settings = state.settings;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x1,
              Space.gutter,
              Space.x4,
            ),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('Remind me to log expenses'),
                  subtitle: const Text(
                    "A gentle nudge on days you haven't logged anything — "
                    'skipped automatically once you have',
                  ),
                  value: settings.enabled,
                  onChanged: (enabled) =>
                      context.read<ReminderSettingsCubit>().setEnabled(
                        enabled: enabled,
                      ),
                ),
              ),
              if (settings.enabled) ...[
                const SizedBox(height: Space.cardGap),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Same time every day'),
                        value: settings.sameTimeForAllDays,
                        onChanged: (sameTime) =>
                            context
                                .read<ReminderSettingsCubit>()
                                .setSameTimeForAllDays(sameTime: sameTime),
                      ),
                      if (settings.sameTimeForAllDays)
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      if (settings.sameTimeForAllDays)
                        ListTile(
                          title: const Text('Time'),
                          trailing: Text(_formatTime(context, settings.uniformTime)),
                          onTap: () => _pickUniformTime(context, settings),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.sectionGap),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, Space.x1),
                  child: Text(
                    'Days',
                    style: AppTypography.chipOverline(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                AppCard(
                  child: Wrap(
                    spacing: Space.x1,
                    runSpacing: Space.x1,
                    children: [
                      for (final weekday in _weekdayShort.keys)
                        FilterChip(
                          label: Text(_weekdayShort[weekday]!),
                          selected: settings.isEnabledFor(weekday),
                          onSelected: (enabled) => context
                              .read<ReminderSettingsCubit>()
                              .setDayEnabled(weekday, enabled: enabled),
                        ),
                    ],
                  ),
                ),
                if (!settings.sameTimeForAllDays) ...[
                  const SizedBox(height: Space.cardGap),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final weekday in _weekdayShort.keys)
                          if (settings.isEnabledFor(weekday)) ...[
                            if (weekday != DateTime.monday)
                              Divider(
                                height: 1,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ListTile(
                              title: Text(_weekdayFull[weekday]!),
                              trailing: Text(
                                _formatTime(
                                  context,
                                  settings.timeFor(weekday),
                                ),
                              ),
                              onTap: () =>
                                  _pickDayTime(context, settings, weekday),
                            ),
                          ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatTime(BuildContext context, ReminderTimeOfDay time) =>
      TimeOfDay(hour: time.hour, minute: time.minute).format(context);

  Future<void> _pickUniformTime(
    BuildContext context,
    ReminderSettings settings,
  ) async {
    final cubit = context.read<ReminderSettingsCubit>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.uniformTime.hour,
        minute: settings.uniformTime.minute,
      ),
    );
    if (picked == null) return;
    await cubit.setUniformTime(
      ReminderTimeOfDay(hour: picked.hour, minute: picked.minute),
    );
  }

  Future<void> _pickDayTime(
    BuildContext context,
    ReminderSettings settings,
    int weekday,
  ) async {
    final cubit = context.read<ReminderSettingsCubit>();
    final current = settings.timeFor(weekday);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await cubit.setDayTime(
      weekday,
      ReminderTimeOfDay(hour: picked.hour, minute: picked.minute),
    );
  }
}
