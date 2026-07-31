import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
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

  final Transaction transaction;

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

  final Transaction transaction;

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
              '${DateFormat('d MMM, HH:mm').format(transaction.transactedAt.toLocal())}',
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

class TransferCandidateTile extends StatelessWidget {
  const TransferCandidateTile({required this.candidate, super.key});

  final TransferCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReviewInboxCubit>();
    final debit = candidate.debit;
    final credit = candidate.credit;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FutureBuilder<List<Account>>(
              future: context.read<AccountRepository>().getAll(),
              builder: (context, snapshot) {
                final accounts = {
                  for (final account in snapshot.data ?? const <Account>[])
                    account.id: account.name,
                };
                final fromName = accounts[debit.accountId] ?? 'Unknown';
                final toName = accounts[credit.accountId] ?? 'Unknown';
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$fromName  →  $toName',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      Money.format(
                        debit.amountMinor,
                        currency: debit.currency,
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${DateFormat('d MMM, HH:mm').format(debit.transactedAt.toLocal())}'
              ' & '
              '${DateFormat('HH:mm').format(credit.transactedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => cubit.dismissTransferCandidate(candidate),
                child: const Text('Not a transfer'),
              ),
              FilledButton(
                onPressed: () => cubit.linkTransfer(candidate),
                child: const Text('Link them'),
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

  final RawCapture capture;

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
              DateFormat('d MMM, HH:mm').format(capture.receivedAt.toLocal()),
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
    return FutureBuilder<List<Category>>(
      future: context.read<CategoryRepository>().getAll(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
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
                label: Text(category.displayName),
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
