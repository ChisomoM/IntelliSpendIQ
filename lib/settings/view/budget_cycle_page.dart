import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/settings/budget_cadence_labels.dart';
import 'package:intellispendiq/settings/cubit/cubit.dart';

/// Choose how successive budget periods are generated.
class BudgetCyclePage extends StatelessWidget {
  const BudgetCyclePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const BudgetCyclePage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          BudgetCycleCubit(context.read<BudgetPeriodRepository>())
            ..loadUnawaited(),
      child: const BudgetCycleView(),
    );
  }
}

class BudgetCycleView extends StatelessWidget {
  const BudgetCycleView({super.key});

  static const _selectable = [
    BudgetCadence.calendarMonth,
    BudgetCadence.payday,
    BudgetCadence.weekly,
    BudgetCadence.biweekly,
    BudgetCadence.everyFourWeeks,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BudgetCycleCubit, BudgetCycleState>(
      listenWhen: (previous, current) =>
          current.savedMessage != null &&
          current.savedMessage != previous.savedMessage,
      listener: (context, state) {
        final message = state.savedMessage;
        if (message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        final schedule = state.schedule;
        final saving = state.status == BudgetCycleStatus.saving;

        return Scaffold(
          appBar: AppBar(title: const Text('Budget cycle')),
          body: schedule == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Budgets, spending progress, and the home summary '
                        'follow this cycle. Reports stay on calendar months.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final cadence in _selectable)
                      ListTile(
                        enabled: !saving,
                        title: Text(BudgetCadenceLabels.title(cadence)),
                        subtitle: Text(BudgetCadenceLabels.subtitle(cadence)),
                        trailing: cadence == schedule.cadence
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => context
                            .read<BudgetCycleCubit>()
                            .selectCadence(cadence),
                      ),
                    if (schedule.cadence == BudgetCadence.payday) ...[
                      const Divider(height: 32),
                      ListTile(
                        enabled: !saving,
                        title: const Text('Payday day of month'),
                        subtitle: Text(
                          'Currently the ${schedule.anchorDay ?? 25}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickAnchorDay(context, schedule.anchorDay ?? 25),
                      ),
                    ],
                    if (schedule.cadence == BudgetCadence.weekly) ...[
                      const Divider(height: 32),
                      ListTile(
                        enabled: !saving,
                        title: const Text('Week starts on'),
                        subtitle: Text(
                          BudgetCadenceLabels.weekday(
                            schedule.startWeekday ?? DateTime.monday,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickWeekday(
                          context,
                          schedule.startWeekday ?? DateTime.monday,
                        ),
                      ),
                    ],
                    if (schedule.cadence == BudgetCadence.biweekly ||
                        schedule.cadence == BudgetCadence.everyFourWeeks) ...[
                      const Divider(height: 32),
                      ListTile(
                        enabled: !saving,
                        title: const Text('Anchor date'),
                        subtitle: Text(
                          _formatAnchor(schedule.anchorDate) ??
                              'Pick the start of a known period',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickAnchorDate(context, schedule.anchorDate),
                      ),
                    ],
                    if (saving)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
        );
      },
    );
  }

  static String? _formatAnchor(String? anchorDate) {
    if (anchorDate == null) return null;
    final parts = anchorDate.split('-');
    if (parts.length != 3) return anchorDate;
    return Iso.formatDateDdMmYyyy(
      DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
    );
  }

  Future<void> _pickAnchorDay(BuildContext context, int current) async {
    final cubit = context.read<BudgetCycleCubit>();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Payday day of month'),
          children: [
            for (var day = 1; day <= 31; day++)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(day),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: day == current ? FontWeight.bold : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (selected != null) await cubit.setAnchorDay(selected);
  }

  Future<void> _pickWeekday(BuildContext context, int current) async {
    final cubit = context.read<BudgetCycleCubit>();
    const days = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Week starts on'),
          children: [
            for (final day in days)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(day),
                child: Text(
                  BudgetCadenceLabels.weekday(day),
                  style: TextStyle(
                    fontWeight: day == current ? FontWeight.bold : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (selected != null) await cubit.setStartWeekday(selected);
  }

  Future<void> _pickAnchorDate(BuildContext context, String? current) async {
    final cubit = context.read<BudgetCycleCubit>();
    final now = DateTime.now();
    var initial = DateTime(now.year, now.month, now.day);
    if (current != null) {
      final parts = current.split('-');
      if (parts.length == 3) {
        initial = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Anchor date (DD/MM/YYYY)',
    );
    if (picked != null) await cubit.setAnchorDate(picked);
  }
}
