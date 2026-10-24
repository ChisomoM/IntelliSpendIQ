import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/nudge_settings_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/nudge_settings.dart';
import 'package:intellispendiq/domain/services/reminder_scheduler.dart';

/// The switch for "ask me what a new transaction was". Lives with the
/// reminder settings because both are local notifications and share the
/// one OS permission, which is requested when this is switched on.
class NudgeSettingsCard extends StatefulWidget {
  const NudgeSettingsCard({super.key});

  @override
  State<NudgeSettingsCard> createState() => _NudgeSettingsCardState();
}

class _NudgeSettingsCardState extends State<NudgeSettingsCard> {
  NudgeSettings _settings = const NudgeSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await context.read<NudgeSettingsRepository>().load();
    if (mounted) setState(() => _settings = loaded);
  }

  Future<void> _setEnabled({required bool enabled}) async {
    final repository = context.read<NudgeSettingsRepository>();
    final reminders = context.read<ReminderService>();
    // Ask for the permission first: switching on with notifications
    // denied would look enabled and never fire.
    final allowed = !enabled || await reminders.requestPermission();
    if (!mounted) return;
    final next = _settings.copyWith(enabled: enabled && allowed);
    setState(() => _settings = next);
    await repository.save(next);
    if (enabled && !allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow notifications for IntelliSpendIQ to use this'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        title: const Text('Ask me what new spending was'),
        subtitle: const Text(
          'A prompt right after a payment the app could not categorize, '
          'so you tag it while you still remember. Quiet from 10pm to 7am',
        ),
        value: _settings.enabled,
        onChanged: (enabled) => _setEnabled(enabled: enabled),
      ),
    );
  }
}
