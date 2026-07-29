import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/transactions/widgets/widgets.dart';
import 'package:intl/intl.dart';

/// The calendar heatmap's day drill-down: every transaction recorded
/// on [day], fetched fresh rather than filtered from an in-memory list
/// so it stays correct if something changed since the month loaded.
Future<void> showDaySpendSheet(
  BuildContext context,
  TransactionRepository transactions,
  DateTime day,
) async {
  final entries = await transactions.transactionsOnDate(day);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DaySpendSheet(day: day, transactions: entries),
  );
}

class _DaySpendSheet extends StatelessWidget {
  const _DaySpendSheet({required this.day, required this.transactions});

  final DateTime day;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = transactions
        .where((tx) => tx.direction == TxDirection.debit)
        .fold<int>(0, (sum, tx) => sum + tx.amountMinor);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, d MMMM').format(day),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (transactions.isNotEmpty)
                    Text(
                      Money.format(total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('No transactions this day.'))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          TransactionTile(transaction: transactions[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}
