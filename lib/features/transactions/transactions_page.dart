import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/features/transactions/transaction_entry_page.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: StreamBuilder<List<TransactionRow>>(
        stream: services.transactions.watchRecent(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                TransactionTile(transaction: rows[index]),
          );
        },
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, super.key});

  final TransactionRow transaction;

  static final _dateFormat = DateFormat('d MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == TxDirection.credit.name;
    final status = TxStatus.fromDbName(transaction.status);
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCredit
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          switch (TxSource.fromName(transaction.source)) {
            TxSource.sms => Icons.sms_outlined,
            TxSource.voice => Icons.mic_none,
            TxSource.notification => Icons.notifications_none,
            TxSource.manual => Icons.edit_outlined,
          },
          size: 20,
        ),
      ),
      title: Text(
        transaction.merchant?.isNotEmpty ?? false
            ? transaction.merchant!
            : 'Unknown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _dateFormat.format(Iso.toDateTime(transaction.transactedAt).toLocal()),
      ),
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
          if (status != TxStatus.confirmed)
            Text(
              status == TxStatus.duplicateSuspect
                  ? 'possible duplicate'
                  : 'needs review',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TransactionEntryPage(existing: transaction),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
