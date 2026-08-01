import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/review/cubit/cubit.dart';
import 'package:intellispendiq/transactions/transactions.dart';
import 'package:intl/intl.dart';

/// A round icon chip carrying the review reason — mirrors
/// [CategoryAvatar]'s shape so a review tile reads as a sibling of the
/// rest of the app rather than a stock `ListTile`.
class _ReasonAvatar extends StatelessWidget {
  const _ReasonAvatar({required this.icon, required this.color});

  final List<List<dynamic>> icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(44 * 0.3),
      ),
      alignment: Alignment.center,
      child: AppIcon(icon, size: 22, color: color),
    );
  }
}

/// One review item's shell: reason avatar + title/subtitle row, an
/// optional body slot (category picker, raw text), and a bottom-right
/// action pair. Every tile in this inbox is one of these, so the list
/// reads as a set rather than four independently-styled cards.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.trailing,
    this.body,
  });

  final List<List<dynamic>> icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? body;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ReasonAvatar(icon: icon, color: iconColor),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle(color: colors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Space.x1),
                  trailing!,
                ],
              ],
            ),
            if (body != null) ...[const SizedBox(height: Space.x1), body!],
            const SizedBox(height: Space.x1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.tertiary(label: secondaryLabel, onPressed: onSecondary),
                const SizedBox(width: Space.x1),
                AppButton.primary(label: primaryLabel, onPressed: onPrimary),
              ],
            ),
          ],
        ),
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
    final money = Theme.of(context).extension<MoneyColors>()!;

    return _ReviewCard(
      icon: AppIcons.review,
      iconColor: money.review,
      title: transaction.merchant ?? 'Unknown merchant',
      subtitle: Money.displayIn(transaction.amountMinor, transaction.currency),
      trailing: transaction.confidence == null
          ? null
          : _ConfidenceChip(confidence: transaction.confidence!),
      body: transaction.categoryId == null
          ? CategoryPicker(
              onSelected: (categoryId) => cubit.categorize(
                transaction.id,
                categoryId,
                merchant: transaction.merchant,
              ),
            )
          : null,
      secondaryLabel: 'Edit',
      onSecondary: () => Navigator.of(
        context,
      ).push<void>(TransactionEntryPage.route(existing: transaction)),
      primaryLabel: 'Confirm',
      onPrimary: () => cubit.confirm(transaction.id),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: money.review.withValues(alpha: 0.12),
        borderRadius: Radii.chipRadius,
      ),
      child: Text(
        '${(confidence * 100).round()}%',
        style: AppTypography.chipOverline(color: money.review),
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
    final money = Theme.of(context).extension<MoneyColors>()!;

    return _ReviewCard(
      icon: AppIcons.moneyOut,
      iconColor: money.review,
      title: transaction.merchant ?? 'Unknown merchant',
      subtitle:
          '${Money.displayIn(transaction.amountMinor, transaction.currency)} · '
          '${DateFormat('d MMM, HH:mm').format(transaction.transactedAt.toLocal())}',
      secondaryLabel: 'Discard duplicate',
      onSecondary: () => cubit.discardDuplicate(transaction.id),
      primaryLabel: 'Keep both',
      onPrimary: () => cubit.confirm(transaction.id),
    );
  }
}

class TransferCandidateTile extends StatelessWidget {
  const TransferCandidateTile({required this.candidate, super.key});

  final TransferCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReviewInboxCubit>();
    final colors = Theme.of(context).colorScheme;
    final debit = candidate.debit;
    final credit = candidate.credit;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ReasonAvatar(icon: AppIcons.transfer, color: colors.primary),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: FutureBuilder<List<Account>>(
                    future: context.read<AccountRepository>().getAll(),
                    builder: (context, snapshot) {
                      final accounts = {
                        for (final account in snapshot.data ?? const <Account>[])
                          account.id: account.name,
                      };
                      final fromName = accounts[debit.accountId] ?? 'Unknown';
                      final toName = accounts[credit.accountId] ?? 'Unknown';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromName  →  $toName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.rowTitle(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('d MMM, HH:mm').format(debit.transactedAt.toLocal())}'
                            ' & '
                            '${DateFormat('HH:mm').format(credit.transactedAt.toLocal())}',
                            style: AppTypography.metadata(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: Space.x1),
                MoneyText(debit.amountMinor, size: MoneySize.meta),
              ],
            ),
            const SizedBox(height: Space.x1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.tertiary(
                  label: 'Not a transfer',
                  onPressed: () => cubit.dismissTransferCandidate(candidate),
                ),
                const SizedBox(width: Space.x1),
                AppButton.primary(
                  label: 'Link them',
                  onPressed: () => cubit.linkTransfer(candidate),
                ),
              ],
            ),
          ],
        ),
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
    final colors = Theme.of(context).colorScheme;

    return _ReviewCard(
      icon: AppIcons.close,
      iconColor: colors.onSurfaceVariant,
      title: capture.sender ?? 'Unknown sender',
      subtitle: DateFormat(
        'd MMM, HH:mm',
      ).format(capture.receivedAt.toLocal()),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.x1),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: Radii.inputRadius,
        ),
        child: Text(
          capture.body,
          style: AppTypography.metadata(color: colors.onSurfaceVariant),
        ),
      ),
      secondaryLabel: 'Not a transaction',
      onSecondary: () => cubit.ignoreCapture(capture.id),
      primaryLabel: 'Enter manually',
      onPrimary: () => Navigator.of(
        context,
      ).push<void>(TransactionEntryPage.route(rawCaptureId: capture.id)),
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
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.x1),
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
    return const EmptyState(
      icon: AppIcons.check,
      title: 'Nothing to review',
      message: 'Everything captured so far was read and saved automatically.',
    );
  }
}
