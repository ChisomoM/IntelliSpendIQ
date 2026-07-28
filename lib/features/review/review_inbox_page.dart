import 'package:flutter/material.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/features/review/review_inbox_state.dart';
import 'package:intellispendiq/features/transactions/transaction_entry_page.dart';
import 'package:intl/intl.dart';

/// The Review Inbox: every capture that needs a human glance, in one
/// place (plan §10.1). Nothing is ever silently dropped — failed parses,
/// low-confidence voice entries, and duplicate suspects all land here.
class ReviewInboxPage extends StatelessWidget {
  const ReviewInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: StreamBuilder<ReviewInboxState>(
        stream: watchReviewInbox(
          transactions: services.transactions,
          rawCaptures: services.rawCaptures,
        ),
        builder: (context, snapshot) {
          final state = snapshot.data ?? const ReviewInboxState();
          if (state.isEmpty) return const _InboxZero();

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (state.duplicates.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Possible duplicates',
                  subtitle:
                      'Same amount and merchant within 30 minutes of an '
                      'existing entry. Keep both if they are real.',
                ),
                for (final transaction in state.duplicates)
                  _DuplicateTile(transaction: transaction),
              ],
              if (state.needsReview.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Needs a detail',
                  subtitle:
                      'Captured, but missing a category or below the '
                      'confidence bar for auto-saving.',
                ),
                for (final transaction in state.needsReview)
                  _NeedsReviewTile(transaction: transaction),
              ],
              if (state.failedCaptures.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Could not read',
                  subtitle:
                      'Messages from a known sender that no parser '
                      'understood. The original text is kept.',
                ),
                for (final capture in state.failedCaptures)
                  _FailedCaptureTile(capture: capture),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsReviewTile extends StatelessWidget {
  const _NeedsReviewTile({required this.transaction});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            title: Text(transaction.merchant ?? 'Unknown merchant'),
            subtitle: Text(
              Money.format(
                transaction.amountMinor,
                currency: transaction.currency,
              ),
            ),
            trailing: transaction.confidence == null
                ? null
                : Chip(
                    label: Text(
                      '${(transaction.confidence! * 100).round()}%',
                    ),
                  ),
          ),
          if (transaction.categoryId == null)
            _CategoryPicker(
              onSelected: (categoryId) => services.transactions.updateFields(
                transaction.id,
                categoryId: categoryId,
                status: TxStatus.confirmed,
              ),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => TransactionEntryPage(existing: transaction),
                  ),
                ),
                child: const Text('Edit'),
              ),
              FilledButton(
                onPressed: () => services.transactions.confirm(transaction.id),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicateTile extends StatelessWidget {
  const _DuplicateTile({required this.transaction});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            title: Text(transaction.merchant ?? 'Unknown merchant'),
            subtitle: Text(
              '${Money.format(transaction.amountMinor, currency: transaction.currency)} · '
              '${DateFormat('d MMM, HH:mm').format(Iso.toDateTime(transaction.transactedAt).toLocal())}',
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    services.transactions.softDelete(transaction.id),
                child: const Text('Discard duplicate'),
              ),
              FilledButton(
                onPressed: () => services.transactions.confirm(transaction.id),
                child: const Text('Keep both'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailedCaptureTile extends StatelessWidget {
  const _FailedCaptureTile({required this.capture});

  final RawCaptureRow capture;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(capture.sender ?? 'Unknown sender'),
            subtitle: Text(
              DateFormat(
                'd MMM, HH:mm',
              ).format(Iso.toDateTime(capture.receivedAt).toLocal()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(capture.body, style: theme.textTheme.bodySmall),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => services.rawCaptures.markIgnored(
                  capture.id,
                  error: 'not_a_transaction',
                ),
                child: const Text('Not a transaction'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionEntryPage(rawCaptureId: capture.id),
                  ),
                ),
                child: const Text('Enter manually'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.onSelected});

  final void Function(String categoryId) onSelected;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return StreamBuilder<List<CategoryRow>>(
      stream: services.categories.watchAll(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <CategoryRow>[];
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ActionChip(
                label: Text('${category.icon ?? ''} ${category.name}'),
                onPressed: () => onSelected(category.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _InboxZero extends StatelessWidget {
  const _InboxZero();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48),
            SizedBox(height: 16),
            Text(
              'Nothing to review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Everything captured so far was read and saved automatically.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
