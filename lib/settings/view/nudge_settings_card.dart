import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/nudge_settings_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/nudge_settings.dart';
import 'package:intellispendiq/domain/services/reminder_scheduler.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';

/// The switch for "ask me what a new transaction was". Lives with the
/// reminder settings because both are local notifications and share the
/// one OS permission, which is requested when this is switched on.
///
/// Also checks the phone's battery restrictions, since a prompt that
/// arrives after the app was closed depends on Android letting the app
/// run in the background.
class NudgeSettingsCard extends StatefulWidget {
  const NudgeSettingsCard({super.key});

  @override
  State<NudgeSettingsCard> createState() => _NudgeSettingsCardState();
}

class _NudgeSettingsCardState extends State<NudgeSettingsCard>
    with WidgetsBindingObserver {
  NudgeSettings _settings = const NudgeSettings();

  /// Null until known (and on a platform with no such setting).
  bool? _unrestricted;

  /// Whether the OS will show this app's notifications at all. Null
  /// until checked.
  bool? _notificationsAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from a system settings screen: show the new status.
    if (state == AppLifecycleState.resumed) {
      _checkBattery();
      _checkNotifications();
    }
  }

  Future<void> _load() async {
    final loaded = await context.read<NudgeSettingsRepository>().load();
    if (mounted) setState(() => _settings = loaded);
    await _checkBattery();
    await _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    if (!mounted) return;
    final reminders = context.read<ReminderService>();
    try {
      final allowed = await reminders.areNotificationsEnabled();
      if (mounted) setState(() => _notificationsAllowed = allowed);
    } on Object {
      // Unknown: say nothing rather than a wrong thing.
    }
  }

  /// Asks the system for the permission and, when it will not ask again
  /// (already refused), sends the user to the app's notification
  /// settings, the only place it can be given back.
  Future<void> _allowNotifications() async {
    final reminders = context.read<ReminderService>();
    final bridge = context.read<CaptureBridge>();
    await reminders.requestPermission();
    if (!await reminders.areNotificationsEnabled()) {
      await bridge.openNotificationSettings();
    }
    await _checkNotifications();
  }

  Future<void> _checkBattery() async {
    if (!mounted) return;
    final bridge = context.read<CaptureBridge>();
    try {
      final unrestricted = await bridge.isIgnoringBatteryOptimizations();
      if (mounted) setState(() => _unrestricted = unrestricted);
    } on Object {
      // No such setting here (not Android): show nothing about it.
    }
  }

  Future<void> _setEnabled({required bool enabled}) async {
    final repository = context.read<NudgeSettingsRepository>();
    final reminders = context.read<ReminderService>();
    // Prompt while the user is looking at the switch, so the system
    // dialog has context.
    if (enabled) await reminders.requestPermission();
    if (!mounted) return;
    // The switch records what the user wants. If the system refused,
    // the banner below explains and offers the way back.
    final next = _settings.copyWith(enabled: enabled);
    setState(() => _settings = next);
    await repository.save(next);
    await _checkNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final restricted = _unrestricted == false;
    final blocked = _notificationsAllowed == false;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Ask me what new spending was'),
            subtitle: const Text(
              'A prompt right after a payment the app could not categorize, '
              'with your usual categories as buttons so one tap files it. '
              'Quiet from 10pm to 7am',
            ),
            value: _settings.enabled,
            onChanged: (enabled) => _setEnabled(enabled: enabled),
          ),
          if (_settings.enabled && blocked) ...[
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Notifications are turned off'),
              subtitle: const Text(
                'Prompts cannot appear until you allow notifications for '
                'IntelliSpendIQ. Tap to allow',
              ),
              onTap: _allowNotifications,
            ),
          ],
          if (_settings.enabled && restricted) ...[
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: const Text('Battery saver may block prompts'),
              subtitle: const Text(
                'When the app is closed, your phone may stop it from '
                'catching a payment. Tap to allow background use',
              ),
              onTap: () => context.read<CaptureBridge>().openBatterySettings(),
            ),
          ],
        ],
      ),
    );
  }
}
