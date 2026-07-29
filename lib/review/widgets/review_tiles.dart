import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/review/cubit/cubit.dart';
import 'package:intellispendiq/transactions/transactions.dart';
import 'package:intl/intl.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.subtitle, super.key});

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

class NeedsReviewTile extends StatelessWidget {
  const NeedsReviewTile({required this.transaction, super.key});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReviewInboxCubit>();
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
                    label: Text('${(transaction.confidence! * 100).round()}%'),
                  ),
          ),
          if (transaction.categoryId == null)
            CategoryPicker(
              onSelected: (categoryId) =>
                  cubit.categorize(transaction.id, categoryId),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  TransactionEntryPage.route(existing: transaction),
                ),
                child: const Text('Edit'),
              ),
              FilledButton(
                onPressed: () => cubit.confirm(transaction.id),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DuplicateTile extends StatelessWidget {
  const DuplicateTile({required this.transaction, super.key});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReviewInboxCubit>();
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
                onPressed: () => cubit.discardDuplicate(transaction.id),
                child: const Text('Discard duplicate'),
              ),
              FilledButton(
                onPressed: () => cubit.confirm(transaction.id),
                child: const Text('Keep both'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FailedCaptureTile extends StatelessWidget {
  const FailedCaptureTile({required this.capture, super.key});

  final RawCaptureRow capture;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReviewInboxCubit>();
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
                onPressed: () => cubit.ignoreCapture(capture.id),
                child: const Text('Not a transaction'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  TransactionEntryPage.route(rawCaptureId: capture.id),
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

/// Horizontal category chips, for tagging an entry without leaving the
/// inbox.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({required this.onSelected, super.key});

  final void Function(String categoryId) onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryRow>>(
      future: context.read<CategoryRepository>().getAll(),
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

class InboxZero extends StatelessWidget {
  const InboxZero({super.key});

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
