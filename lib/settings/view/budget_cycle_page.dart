import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/design/design.dart';
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
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Budget cycle')),
          body: schedule == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x1,
                    Space.gutter,
                    Space.x4,
                  ),
                  children: [
                    Text(
                      'Budgets, spending progress, and the home summary '
                      'follow this cycle. Reports stay on calendar months.',
                      style: AppTypography.body(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: Space.x2),
                    _CadenceGroup(
                      cadences: _selectable,
                      selected: schedule.cadence,
                      enabled: !saving,
                      onSelected: (cadence) =>
                          context.read<BudgetCycleCubit>().selectCadence(cadence),
                    ),
                    if (schedule.cadence == BudgetCadence.payday) ...[
                      const SizedBox(height: Space.sectionGap),
                      _DetailGroup(
                        title: 'Payday day of month',
                        value: 'Currently the ${schedule.anchorDay ?? 25}',
                        enabled: !saving,
                        onTap: () =>
                            _pickAnchorDay(context, schedule.anchorDay ?? 25),
                      ),
                    ],
                    if (schedule.cadence == BudgetCadence.weekly) ...[
                      const SizedBox(height: Space.sectionGap),
                      _DetailGroup(
                        title: 'Week starts on',
                        value: BudgetCadenceLabels.weekday(
                          schedule.startWeekday ?? DateTime.monday,
                        ),
                        enabled: !saving,
                        onTap: () => _pickWeekday(
                          context,
                          schedule.startWeekday ?? DateTime.monday,
                        ),
                      ),
                    ],
                    if (schedule.cadence == BudgetCadence.biweekly ||
                        schedule.cadence == BudgetCadence.everyFourWeeks) ...[
                      const SizedBox(height: Space.sectionGap),
                      _DetailGroup(
                        title: 'Anchor date',
                        value: _formatAnchor(schedule.anchorDate) ??
                            'Pick the start of a known period',
                        enabled: !saving,
                        onTap: () => _pickAnchorDate(context, schedule.anchorDate),
                      ),
                    ],
                    if (saving) ...[
                      const SizedBox(height: Space.x2),
                      const Center(child: CircularProgressIndicator()),
                    ],
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

/// Every selectable cadence, grouped into one card with a checkmark on
/// the active one — the shape Settings' own sections use, so this page
/// reads as a continuation of it rather than a different screen.
class _CadenceGroup extends StatelessWidget {
  const _CadenceGroup({
    required this.cadences,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final List<BudgetCadence> cadences;
  final BudgetCadence selected;
  final bool enabled;
  final ValueChanged<BudgetCadence> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < cadences.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.outlineVariant),
            AppListRow(
              title: Text(BudgetCadenceLabels.title(cadences[i])),
              subtitle: Text(BudgetCadenceLabels.subtitle(cadences[i])),
              trailing: cadences[i] == selected
                  ? AppIcon(AppIcons.check, size: 20, color: colors.primary)
                  : null,
              onTap: enabled ? () => onSelected(cadences[i]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable detail row (payday, week start, anchor date) in its own
/// card, matching the group shape above.
class _DetailGroup extends StatelessWidget {
  const _DetailGroup({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: AppListRow(
        title: Text(title),
        subtitle: Text(value),
        trailing: AppIcon(
          AppIcons.chevronRight,
          size: 18,
          color: colors.onSurfaceVariant,
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
