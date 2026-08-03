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
import 'package:intellispendiq/review/open_review_details.dart';
import 'package:intellispendiq/review/review_detail_target.dart';
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

/// Compact list row for the inbox. Tap opens Review details;
/// decisions live there rather than on the list itself.
class _ReviewListTile extends StatelessWidget {
  const _ReviewListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final List<List<dynamic>> icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        onTap: onTap,
        child: Row(
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
            const SizedBox(width: Space.x1),
            AppIcon(
              AppIcons.chevronRight,
              size: 18,
              color: colors.onSurfaceVariant,
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
    final money = Theme.of(context).extension<MoneyColors>()!;

    return _ReviewListTile(
      icon: AppIcons.review,
      iconColor: money.review,
      title: transaction.merchant ?? 'Unknown merchant',
      subtitle: Money.displayIn(transaction.amountMinor, transaction.currency),
      trailing: transaction.confidence == null
          ? null
          : _ConfidenceChip(confidence: transaction.confidence!),
      onTap: () => openReviewDetails(
        context,
        NeedsReviewDetail(transaction),
      ),
    );
  }
}

class UncategorizedTile extends StatelessWidget {
  const UncategorizedTile({required this.transaction, super.key});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;

    return _ReviewListTile(
      icon: AppIcons.budgets,
      iconColor: money.review,
      title: transaction.merchant ?? 'Unknown merchant',
      subtitle:
          '${Money.displayIn(transaction.amountMinor, transaction.currency)} · '
          'uncategorized',
      onTap: () => openReviewDetails(
        context,
        UncategorizedDetail(transaction),
      ),
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
    final money = Theme.of(context).extension<MoneyColors>()!;

    return _ReviewListTile(
      icon: AppIcons.moneyOut,
      iconColor: money.review,
      title: transaction.merchant ?? 'Unknown merchant',
      subtitle:
          '${Money.displayIn(transaction.amountMinor, transaction.currency)} · '
          '${DateFormat('d MMM, HH:mm').format(transaction.transactedAt.toLocal())}',
      onTap: () => openReviewDetails(
        context,
        DuplicateReviewDetail(transaction),
      ),
    );
  }
}

class TransferCandidateTile extends StatelessWidget {
  const TransferCandidateTile({required this.candidate, super.key});

  final TransferCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final debit = candidate.debit;
    final credit = candidate.credit;

    return FutureBuilder<List<Account>>(
      future: context.read<AccountRepository>().getAll(),
      builder: (context, snapshot) {
        final accounts = {
          for (final account in snapshot.data ?? const <Account>[])
            account.id: account.name,
        };
        final fromName = accounts[debit.accountId] ?? 'Unknown';
        final toName = accounts[credit.accountId] ?? 'Unknown';

        return _ReviewListTile(
          icon: AppIcons.transfer,
          iconColor: colors.primary,
          title: '$fromName  →  $toName',
          subtitle:
              '${DateFormat('d MMM, HH:mm').format(debit.transactedAt.toLocal())}'
              ' & '
              '${DateFormat('HH:mm').format(credit.transactedAt.toLocal())}',
          trailing: MoneyText(debit.amountMinor, size: MoneySize.meta),
          onTap: () => openReviewDetails(
            context,
            TransferCandidateDetail(candidate),
          ),
        );
      },
    );
  }
}

class FailedCaptureTile extends StatelessWidget {
  const FailedCaptureTile({required this.capture, super.key});

  final RawCapture capture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _ReviewListTile(
      icon: AppIcons.close,
      iconColor: colors.onSurfaceVariant,
      title: capture.sender ?? 'Unknown sender',
      subtitle: DateFormat(
        'd MMM, HH:mm',
      ).format(capture.receivedAt.toLocal()),
      onTap: () => openReviewDetails(
        context,
        FailedCaptureDetail(capture),
      ),
    );
  }
}

/// Horizontal category chips, for tagging an entry from Review details
/// without opening the full editor.
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
