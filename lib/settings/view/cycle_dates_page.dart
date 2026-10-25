import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/services/budget_period_generator.dart';

/// Lets the user change where budget cycles begin and end, one cycle at a
/// time. The schedule's rule ("the 25th") still decides cycles nobody has
/// touched; this adjusts the exceptions, such as a payday that landed on
/// the 23rd.
class CycleDatesPage extends StatefulWidget {
  const CycleDatesPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const CycleDatesPage());
  }

  @override
  State<CycleDatesPage> createState() => _CycleDatesPageState();
}

class _CycleDatesPageState extends State<CycleDatesPage> {
  late Future<_Cycles> _cycles = _load();
  bool _busy = false;

  Future<_Cycles> _load() async {
    final periods = context.read<BudgetPeriodRepository>();
    final transactions = context.read<TransactionRepository>();
    final now = DateTime.now();
    final current = await periods.ensurePeriodContaining(now);
    final next = await periods.shiftPeriod(current, 1);
    final earliest = await transactions.earliestTransactionAt() ?? now;
    final list = await periods.cyclesBetween(
      earliest: earliest,
      now: _day(next.startAt),
    );
    return _Cycles(current: current, next: next, list: list);
  }

  static DateTime _day(String iso) {
    final local = Iso.toDateTime(iso).toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  void _reload() => setState(() => _cycles = _load());

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Confirms with the user what a move will do, then does it.
  Future<void> _confirmAndMove({
    required BudgetPeriod earlier,
    required BudgetPeriod later,
    required DateTime newBoundary,
  }) async {
    final periods = context.read<BudgetPeriodRepository>();
    setState(() => _busy = true);
    try {
      final preview = await periods.previewBoundaryMove(
        earlierId: earlier.id,
        laterId: later.id,
        newBoundary: newBoundary,
      );
      if (!mounted) return;
      final count = preview.transactionsMoving;
      final direction = preview.movesIntoLater
          ? 'from the earlier cycle into the later one'
          : 'from the later cycle back into the earlier one';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change cycle dates?'),
          content: Text(
            'The earlier cycle will run ${preview.earlierLabel}.\n'
            'The later cycle will run ${preview.laterLabel}.\n\n'
            '${count == 0 ? 'No transactions move.' : '$count transaction(s) move $direction.'}\n\n'
            'Budgets you already set stay with the cycle they were set on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Change dates'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await periods.moveBoundary(
        earlierId: earlier.id,
        laterId: later.id,
        newBoundary: newBoundary,
      );
      if (!mounted) return;
      _say('Cycle dates updated.');
      _reload();
    } on CycleEditException catch (error) {
      if (mounted) _say(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Start next cycle today": the boundary between the current and next
  /// cycle becomes today.
  Future<void> _startNextCycleToday(_Cycles cycles) {
    final now = DateTime.now();
    return _confirmAndMove(
      earlier: cycles.current,
      later: cycles.next,
      newBoundary: DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> _edit(LocalPeriodBounds bounds) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(Iso.periodLabel(bounds.start, bounds.endExclusive)),
              subtitle: const Text('What do you want to change?'),
            ),
            ListTile(
              leading: const Icon(Icons.first_page),
              title: const Text('Change the start date'),
              subtitle: const Text('Also changes the end of the cycle before'),
              onTap: () => Navigator.of(sheetContext).pop('start'),
            ),
            ListTile(
              leading: const Icon(Icons.last_page),
              title: const Text('Change the last day'),
              subtitle: const Text('Also changes the start of the cycle after'),
              onTap: () => Navigator.of(sheetContext).pop('end'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final periods = context.read<BudgetPeriodRepository>();
    final period = await periods.ensurePeriodContaining(bounds.start);
    if (!mounted) return;
    final start = _day(period.startAt);
    final endExclusive = _day(period.endAt);

    if (choice == 'start') {
      final earlier = await periods.shiftPeriod(period, -1);
      if (!mounted) return;
      final picked = await showDatePicker(
        context: context,
        helpText: 'New start date',
        initialDate: start,
        firstDate: _day(earlier.startAt).add(const Duration(days: 1)),
        lastDate: DateTime(
          endExclusive.year,
          endExclusive.month,
          endExclusive.day - 1,
        ),
      );
      if (picked == null || !mounted) return;
      await _confirmAndMove(
        earlier: earlier,
        later: period,
        newBoundary: picked,
      );
    } else {
      final later = await periods.shiftPeriod(period, 1);
      if (!mounted) return;
      final laterEnd = _day(later.endAt);
      final picked = await showDatePicker(
        context: context,
        helpText: 'New last day',
        initialDate: DateTime(
          endExclusive.year,
          endExclusive.month,
          endExclusive.day - 1,
        ),
        firstDate: start,
        lastDate: DateTime(laterEnd.year, laterEnd.month, laterEnd.day - 2),
      );
      if (picked == null || !mounted) return;
      await _confirmAndMove(
        earlier: period,
        later: later,
        newBoundary: DateTime(picked.year, picked.month, picked.day + 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle dates')),
      body: FutureBuilder<_Cycles>(
        future: _cycles,
        builder: (context, snapshot) {
          final cycles = snapshot.data;
          if (cycles == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final today = DateTime.now();
          final today0 = DateTime(today.year, today.month, today.day);
          final currentStart = _day(cycles.current.startAt);
          final nextStart = _day(cycles.next.startAt);
          final canStartToday =
              today0.isAfter(currentStart) && today0.isBefore(nextStart);

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x1,
                Space.gutter,
                Space.x4,
              ),
              children: [
                Text(
                  'Got paid earlier or later than usual? Move where a cycle '
                  'starts so that payday and what you spend from it land in '
                  'the right cycle. Cycles you do not touch keep following '
                  'your schedule.',
                  style: AppTypography.body(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.x2),
                if (canStartToday)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppListRow(
                      title: const Text('Start the next cycle today'),
                      subtitle: Text(
                        'Instead of ${Iso.formatDateDdMmYyyy(nextStart)}',
                      ),
                      trailing: AppIcon(
                        AppIcons.chevronRight,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      onTap: () => _startNextCycleToday(cycles),
                    ),
                  ),
                const SizedBox(height: Space.x2),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final bounds in cycles.list)
                        AppListRow(
                          title: Text(
                            Iso.periodLabel(bounds.start, bounds.endExclusive),
                          ),
                          subtitle: _tag(bounds, currentStart, nextStart) == null
                              ? null
                              : Text(_tag(bounds, currentStart, nextStart)!),
                          trailing: AppIcon(
                            AppIcons.chevronRight,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          onTap: () => _edit(bounds),
                        ),
                    ],
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: Space.x2),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String? _tag(
    LocalPeriodBounds bounds,
    DateTime currentStart,
    DateTime nextStart,
  ) {
    if (bounds.start == currentStart) return 'Current cycle';
    if (bounds.start == nextStart) return 'Next cycle';
    return null;
  }
}

class _Cycles {
  const _Cycles({
    required this.current,
    required this.next,
    required this.list,
  });

  final BudgetPeriod current;
  final BudgetPeriod next;

  /// Newest first, starting with the next cycle.
  final List<LocalPeriodBounds> list;
}
