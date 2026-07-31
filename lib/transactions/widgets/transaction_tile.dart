import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/transactions/view/view.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, super.key});

  final Transaction transaction;

  static final _dateFormat = DateFormat('d MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == TxDirection.credit;
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCredit
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          switch (transaction.source) {
            TxSource.sms => Icons.sms_outlined,
            TxSource.voice => Icons.mic_none,
            TxSource.notification => Icons.notifications_none,
            TxSource.manual => Icons.edit_outlined,
          },
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              transaction.merchant?.isNotEmpty ?? false
                  ? transaction.merchant!
                  : 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (transaction.receiptPath != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.attach_file,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: Text(_dateFormat.format(transaction.transactedAt.toLocal())),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isCredit ? '+' : '-'}${Money.format(transaction.amountMinor, currency: transaction.currency)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isCredit ? theme.colorScheme.tertiary : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (transaction.status != TxStatus.confirmed)
            Text(
              switch (transaction.status) {
                TxStatus.duplicateSuspect => 'possible duplicate',
                TxStatus.planned => 'planned',
                TxStatus.needsReview || TxStatus.confirmed => 'needs review',
              },
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      onTap: () => Navigator.of(
        context,
      ).push<void>(TransactionEntryPage.route(existing: transaction)),
    );
  }
}

/// Renders a confirmed [Transfer] — money moved between two of the
/// user's own accounts — as a neutral row, distinct from a debit or
/// credit transaction. Not dismissible: unlinking a transfer back into
/// two separate transactions isn't supported.
class TransferTile extends StatelessWidget {
  const TransferTile({
    required this.transfer,
    required this.fromAccountName,
    required this.toAccountName,
    super.key,
  });

  final Transfer transfer;
  final String fromAccountName;
  final String toAccountName;

  static final _dateFormat = DateFormat('d MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.swap_horiz, size: 20),
      ),
      title: Text(
        '$fromAccountName  →  $toAccountName',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_dateFormat.format(transfer.transactedAt.toLocal())),
      trailing: Text(
        Money.format(transfer.amountMinor),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class NoTransactionsYet extends StatelessWidget {
  const NoTransactionsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48),
            SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Bank and mobile money alerts are captured automatically once '
              'SMS access is granted. You can also add one by hand or by voice.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
