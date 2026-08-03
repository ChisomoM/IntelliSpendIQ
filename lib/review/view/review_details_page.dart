import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/services/merchant_categorizer.dart';
import 'package:intellispendiq/review/cubit/cubit.dart';
import 'package:intellispendiq/review/review_detail_target.dart';
import 'package:intellispendiq/review/widgets/widgets.dart';
import 'package:intellispendiq/transactions/view/transaction_entry_page.dart';
import 'package:intl/intl.dart';

/// Full detail + actions for one Review Inbox item. The list itself is
/// a glance; decisions happen here.
class ReviewDetailsPage extends StatelessWidget {
  const ReviewDetailsPage({required this.target, super.key});

  final ReviewDetailTarget target;

  static Route<bool> route(ReviewDetailTarget target) {
    return MaterialPageRoute<bool>(
      builder: (_) => ReviewDetailsPage(target: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReviewInboxCubit(
        transactions: context.read<TransactionRepository>(),
        rawCaptures: context.read<RawCaptureRepository>(),
        transfers: context.read<TransferRepository>(),
        categorizer: context.read<MerchantCategorizer>(),
      ),
      child: ReviewDetailsView(target: target),
    );
  }
}

class ReviewDetailsView extends StatelessWidget {
  const ReviewDetailsView({required this.target, super.key});

  final ReviewDetailTarget target;

  static final _dateFormat = DateFormat('d MMM yyyy, HH:mm');

  Future<void> _done(BuildContext context, {bool resolved = true}) async {
    if (!context.mounted) return;
    Navigator.of(context).pop(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final cubit = context.read<ReviewInboxCubit>();

    return switch (target) {
      NeedsReviewDetail(:final transaction) => Scaffold(
        appBar: AppBar(title: const Text('Needs a detail')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x2,
            Space.gutter,
            Space.x4,
          ),
          children: [
            _DetailHeader(
              icon: AppIcons.review,
              iconColor: money.review,
              title: transaction.merchant ?? 'Unknown merchant',
              subtitle: Money.displayIn(
                transaction.amountMinor,
                transaction.currency,
              ),
              trailing: transaction.confidence == null
                  ? null
                  : Text(
                      '${(transaction.confidence! * 100).round()}% confidence',
                      style: AppTypography.metadata(color: money.review),
                    ),
            ),
            const SizedBox(height: Space.x1),
            Text(
              _dateFormat.format(transaction.transactedAt.toLocal()),
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
            if (transaction.description != null) ...[
              const SizedBox(height: Space.x2),
              Text(
                transaction.description!,
                style: AppTypography.body(color: colors.onSurface),
              ),
            ],
            if (transaction.categoryId == null) ...[
              const SizedBox(height: Space.x3),
              Text(
                'CATEGORY',
                style: AppTypography.chipOverline(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.x1),
              CategoryPicker(
                onSelected: (categoryId) async {
                  await cubit.categorize(
                    transaction.id,
                    categoryId,
                    merchant: transaction.merchant,
                  );
                  if (context.mounted) await _done(context);
                },
              ),
            ],
            const SizedBox(height: Space.x3),
            AppButton.primary(
              label: 'Confirm',
              onPressed: () async {
                await cubit.confirm(transaction.id);
                if (context.mounted) await _done(context);
              },
            ),
            const SizedBox(height: Space.x1),
            AppButton.secondary(
              label: 'Edit entry',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  TransactionEntryPage.route(existing: transaction),
                );
                if (context.mounted) await _done(context);
              },
            ),
          ],
        ),
      ),
      UncategorizedDetail(:final transaction) => Scaffold(
        appBar: AppBar(title: const Text('Needs a category')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x2,
            Space.gutter,
            Space.x4,
          ),
          children: [
            _DetailHeader(
              icon: AppIcons.budgets,
              iconColor: money.review,
              title: transaction.merchant ?? 'Unknown merchant',
              subtitle: Money.displayIn(
                transaction.amountMinor,
                transaction.currency,
              ),
            ),
            const SizedBox(height: Space.x1),
            Text(
              _dateFormat.format(transaction.transactedAt.toLocal()),
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x2),
            Text(
              'This entry is saved and counts toward your totals, but it '
              'has no category yet. Tagging it keeps budgets and reports '
              'accurate — and teaches the app for next time.',
              style: AppTypography.body(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x3),
            Text(
              'CATEGORY',
              style: AppTypography.chipOverline(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.x1),
            CategoryPicker(
              onSelected: (categoryId) async {
                await cubit.categorize(
                  transaction.id,
                  categoryId,
                  merchant: transaction.merchant,
                );
                if (context.mounted) await _done(context);
              },
            ),
            const SizedBox(height: Space.x3),
            AppButton.secondary(
              label: 'Edit entry',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  TransactionEntryPage.route(existing: transaction),
                );
                if (context.mounted) await _done(context);
              },
            ),
          ],
        ),
      ),
      DuplicateReviewDetail(:final transaction) => Scaffold(
        appBar: AppBar(title: const Text('Possible duplicate')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x2,
            Space.gutter,
            Space.x4,
          ),
          children: [
            _DetailHeader(
              icon: AppIcons.moneyOut,
              iconColor: money.review,
              title: transaction.merchant ?? 'Unknown merchant',
              subtitle: Money.displayIn(
                transaction.amountMinor,
                transaction.currency,
              ),
            ),
            const SizedBox(height: Space.x1),
            Text(
              _dateFormat.format(transaction.transactedAt.toLocal()),
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x2),
            Text(
              'Same amount and merchant within 30 minutes of an existing '
              'entry. Keep both if they are real.',
              style: AppTypography.body(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x3),
            AppButton.primary(
              label: 'Keep both',
              onPressed: () async {
                await cubit.confirm(transaction.id);
                if (context.mounted) await _done(context);
              },
            ),
            const SizedBox(height: Space.x1),
            AppButton.secondary(
              label: 'Discard duplicate',
              onPressed: () async {
                await cubit.discardDuplicate(transaction.id);
                if (context.mounted) await _done(context);
              },
            ),
          ],
        ),
      ),
      TransferCandidateDetail(:final candidate) => Scaffold(
        appBar: AppBar(title: const Text('Possible transfer')),
        body: FutureBuilder<List<Account>>(
          future: context.read<AccountRepository>().getAll(),
          builder: (context, snapshot) {
            final accounts = {
              for (final account in snapshot.data ?? const <Account>[])
                account.id: account.name,
            };
            final debit = candidate.debit;
            final credit = candidate.credit;
            final fromName = accounts[debit.accountId] ?? 'Unknown';
            final toName = accounts[credit.accountId] ?? 'Unknown';

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x2,
                Space.gutter,
                Space.x4,
              ),
              children: [
                _DetailHeader(
                  icon: AppIcons.transfer,
                  iconColor: colors.primary,
                  title: '$fromName  →  $toName',
                  subtitle: Money.displayIn(
                    debit.amountMinor,
                    debit.currency,
                  ),
                ),
                const SizedBox(height: Space.x2),
                Text(
                  'A debit and a credit of the same amount on two of your '
                  'accounts, close together in time. Linking them records '
                  'one transfer and removes both from spend and income.',
                  style: AppTypography.body(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.x3),
                _LegRow(
                  label: 'From',
                  accountName: fromName,
                  merchant: debit.merchant,
                  at: debit.transactedAt,
                ),
                const SizedBox(height: Space.x2),
                _LegRow(
                  label: 'To',
                  accountName: toName,
                  merchant: credit.merchant,
                  at: credit.transactedAt,
                ),
                const SizedBox(height: Space.x3),
                AppButton.primary(
                  label: 'Link them',
                  onPressed: () async {
                    await cubit.linkTransfer(candidate);
                    // `true` so Edit entry can close after a successful link.
                    if (context.mounted) await _done(context);
                  },
                ),
                const SizedBox(height: Space.x1),
                AppButton.secondary(
                  label: 'Not a transfer',
                  onPressed: () async {
                    await cubit.dismissTransferCandidate(candidate);
                    // Dismiss keeps the original entry; Edit entry stays open.
                    if (context.mounted) await _done(context, resolved: false);
                  },
                ),
              ],
            );
          },
        ),
      ),
      FailedCaptureDetail(:final capture) => Scaffold(
        appBar: AppBar(title: const Text('Could not read')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x2,
            Space.gutter,
            Space.x4,
          ),
          children: [
            _DetailHeader(
              icon: AppIcons.close,
              iconColor: colors.onSurfaceVariant,
              title: capture.sender ?? 'Unknown sender',
              subtitle: _dateFormat.format(capture.receivedAt.toLocal()),
            ),
            const SizedBox(height: Space.x2),
            Text(
              'Messages from a known sender that no parser understood. '
              'The original text is kept.',
              style: AppTypography.body(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.x2),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: Radii.inputRadius,
              ),
              child: Text(
                capture.body,
                style: AppTypography.body(color: colors.onSurface),
              ),
            ),
            const SizedBox(height: Space.x3),
            AppButton.primary(
              label: 'Enter manually',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  TransactionEntryPage.route(rawCaptureId: capture.id),
                );
                if (context.mounted) await _done(context);
              },
            ),
            const SizedBox(height: Space.x1),
            AppButton.secondary(
              label: 'Not a transaction',
              onPressed: () async {
                await cubit.ignoreCapture(capture.id);
                if (context.mounted) await _done(context);
              },
            ),
          ],
        ),
      ),
    };
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final List<List<dynamic>> icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(48 * 0.3),
          ),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(width: Space.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.sectionHeader(color: colors.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.rowTitle(color: colors.onSurface),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({
    required this.label,
    required this.accountName,
    required this.at,
    this.merchant,
  });

  final String label;
  final String accountName;
  final String? merchant;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.chipOverline(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.x1),
          Text(
            accountName,
            style: AppTypography.rowTitle(color: colors.onSurface),
          ),
          if (merchant != null) ...[
            const SizedBox(height: 2),
            Text(
              merchant!,
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            DateFormat('d MMM, HH:mm').format(at.toLocal()),
            style: AppTypography.metadata(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
