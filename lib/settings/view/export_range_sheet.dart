import 'package:flutter/material.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/services/backup_service.dart';
import 'package:intellispendiq/domain/services/budget_period_generator.dart';

/// Asks which window an export should cover: everything, a custom date
/// range, or one of the user's budget cycles. Resolves to null if the
/// sheet is dismissed.
Future<ExportRange?> pickExportRange(
  BuildContext context, {
  required BudgetPeriodRepository budgetPeriods,
  required TransactionRepository transactions,
}) {
  return showModalBottomSheet<ExportRange>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExportRangeSheet(
      budgetPeriods: budgetPeriods,
      transactions: transactions,
    ),
  );
}

class _ExportRangeSheet extends StatefulWidget {
  const _ExportRangeSheet({
    required this.budgetPeriods,
    required this.transactions,
  });

  final BudgetPeriodRepository budgetPeriods;
  final TransactionRepository transactions;

  @override
  State<_ExportRangeSheet> createState() => _ExportRangeSheetState();
}

class _ExportRangeSheetState extends State<_ExportRangeSheet> {
  late final Future<List<LocalPeriodBounds>> _cycles = _loadCycles();

  Future<List<LocalPeriodBounds>> _loadCycles() async {
    final now = DateTime.now();
    final earliest = await widget.transactions.earliestTransactionAt() ?? now;
    return widget.budgetPeriods.cyclesBetween(earliest: earliest, now: now);
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month, now.day),
      ),
    );
    if (picked == null || !mounted) return;
    // The picker's end is a day, inclusive; the export's is exclusive.
    final toExclusive = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day + 1,
    );
    Navigator.of(context).pop(
      ExportRange(
        from: DateTime(picked.start.year, picked.start.month, picked.start.day),
        toExclusive: toExclusive,
        label: Iso.periodLabel(picked.start, toExclusive),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: FutureBuilder<List<LocalPeriodBounds>>(
          future: _cycles,
          builder: (context, snapshot) {
            final cycles = snapshot.data ?? const <LocalPeriodBounds>[];
            return ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Text('Export which transactions?'),
                ),
                ListTile(
                  title: const Text('All time'),
                  onTap: () => Navigator.of(context).pop(ExportRange.allTime),
                ),
                ListTile(
                  title: const Text('Custom date range'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickCustom,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x2,
                    Space.gutter,
                    Space.x1,
                  ),
                  child: Text('Budget cycles'),
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(Space.x2),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final (index, cycle) in cycles.indexed)
                  ListTile(
                    title: Text(
                      Iso.periodLabel(cycle.start, cycle.endExclusive),
                    ),
                    subtitle: index == 0 ? const Text('Current cycle') : null,
                    onTap: () => Navigator.of(context).pop(
                      ExportRange(
                        from: cycle.start,
                        toExclusive: cycle.endExclusive,
                        label: Iso.periodLabel(cycle.start, cycle.endExclusive),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
