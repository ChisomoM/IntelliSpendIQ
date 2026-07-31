import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/dashboard/cubit/cubit.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intl/intl.dart';

/// Wordmark, review entry, and settings — the persistent chrome at the
/// top of Home. Review's badge lives here rather than on the Home tab
/// icon, where it used to point at a destination that was not the
/// inbox.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.pendingReviewCount,
    required this.onOpenReview,
    required this.onOpenSettings,
    super.key,
  });

  final int pendingReviewCount;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Wordmark(size: 22)),
        IconButton(
          onPressed: onOpenReview,
          tooltip: pendingReviewCount == 0
              ? 'Review inbox'
              : '$pendingReviewCount waiting in the review inbox',
          icon: Badge(
            // Counts above 99 would push the badge wider than the icon
            // it sits on; the exact number stops mattering long before
            // that and the banner below carries it in full anyway.
            label: Text(pendingReviewCount > 99 ? '99+' : '$pendingReviewCount'),
            isLabelVisible: pendingReviewCount > 0,
            child: AppIcon(AppIcons.bell),
          ),
        ),
        IconButton(
          onPressed: onOpenSettings,
          tooltip: 'Settings',
          icon: AppIcon(AppIcons.settings),
        ),
      ],
    );
  }
}

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.periodLabel,
    required this.isCurrentPeriod,
    super.key,
  });

  /// Human-readable window, e.g. `1 – 31 Jul`.
  final String periodLabel;

  /// Whether [periodLabel] covers today, which decides the tense.
  final bool isCurrentPeriod;

  String get _greeting => switch (DateTime.now().hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // The stored period label is machine output (`01/07/2026 –
    // 31/07/2026`) and used to be dropped straight into this sentence.
    final subtitle = periodLabel.isEmpty
        ? "Here's how your money is doing"
        : isCurrentPeriod
        ? "Here's how $periodLabel is going"
        : "Here's how $periodLabel went";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting, style: AppTypography.screenTitle(color: colors.onSurface)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.body(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Spend for the period against whatever it is measured against, on a
/// dark card in both themes — the one place cyan/violet-300 are allowed
/// as a fill, because the surface under them is dark either way.
class SpendHeroCard extends StatelessWidget {
  const SpendHeroCard({
    required this.totalSpent,
    required this.planMinor,
    required this.planSource,
    required this.planRatio,
    required this.isOverPlan,
    required this.daysLeft,
    required this.isCurrentPeriod,
    required this.onTap,
    super.key,
  });

  final int totalSpent;
  final int? planMinor;
  final PlanSource planSource;
  final double planRatio;
  final bool isOverPlan;
  final int daysLeft;
  final bool isCurrentPeriod;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.night800 : AppColors.ink900;
    const onSurface = AppColors.nightText;
    const onSurfaceMuted = AppColors.nightText2;
    // This card is dark in both themes, so it takes the dark-mode
    // money colours regardless of brightness rather than reading
    // MoneyColors — light mode's outflow (#B91C1C) on an ink900 card
    // would be a dark red on near-black.
    const overColor = AppColors.outflowD;

    return Material(
      color: surface,
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPENT THIS PERIOD',
                style: AppTypography.chipOverline(color: onSurfaceMuted),
              ),
              const SizedBox(height: Space.x1),
              MoneyText(
                totalSpent,
                size: MoneySize.display,
                color: onSurface,
              ),
              if (planMinor != null) ...[
                const SizedBox(height: Space.x2),
                ProgressMeter(
                  value: planRatio,
                  isOver: isOverPlan,
                  onDarkSurface: true,
                ),
                const SizedBox(height: Space.x1),
                // Colour never stands alone: the overspend is stated in
                // words as well as carried by the meter's hue.
                Text(
                  _planSentence(),
                  style: AppTypography.metadata(
                    color: isOverPlan ? overColor : onSurfaceMuted,
                  ),
                ),
              ] else ...[
                const SizedBox(height: Space.x1),
                Text(
                  'Set a budget to track this against a plan.',
                  style: AppTypography.metadata(color: onSurfaceMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _planSentence() {
    final plan = planMinor!;
    final source = planSource == PlanSource.income ? 'income' : 'budget';
    final tail = isCurrentPeriod
        ? ', ${daysLeft == 1 ? '1 day' : '$daysLeft days'} left'
        : '';

    if (isOverPlan) {
      return '${Money.display(totalSpent - plan)} over $source$tail';
    }
    return '${Money.display(plan - totalSpent)} left of '
        '${Money.display(plan)} $source$tail';
  }
}

/// Every account's ledger-derived balance, scrolled horizontally. Was
/// three taps deep under Settings before this.
class AccountBalanceStrip extends StatelessWidget {
  const AccountBalanceStrip({
    required this.accounts,
    required this.balances,
    required this.onOpenAccounts,
    super.key,
  });

  final List<Account> accounts;
  final Map<String, int> balances;
  final VoidCallback onOpenAccounts;

  static List<List<dynamic>> _iconFor(AccountType type) => switch (type) {
    AccountType.cash => AppIcons.accountCash,
    AccountType.bank => AppIcons.accountBank,
    AccountType.mobileMoney => AppIcons.accountMobileMoney,
    AccountType.card => AppIcons.accountCard,
  };

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    // A horizontal list needs a bound height, so it has to be derived
    // rather than left to the content: card padding + icon + gaps,
    // plus the two text lines at whatever the system font scale is.
    // A fixed height would clip the balance at large scales.
    final textScaler = MediaQuery.textScalerOf(context);
    final stripHeight =
        Space.cardPadding * 2 +
        20 +
        Space.x1 +
        2 +
        textScaler.scale(18) +
        textScaler.scale(22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Accounts',
          action: 'Manage',
          onActionTap: onOpenAccounts,
        ),
        SizedBox(
          height: stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.x1),
            itemBuilder: (context, index) {
              final account = accounts[index];
              final balance = balances[account.id] ?? 0;

              return SizedBox(
                width: 168,
                child: AppCard(
                  onTap: onOpenAccounts,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        _iconFor(account.type),
                        size: 20,
                        color: colors.secondary,
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // A negative balance is real — an overdrawn
                      // account, or spend logged against an account
                      // whose opening balance was never set — so it
                      // renders as a true minus rather than being
                      // clamped to zero.
                      MoneyText(balance),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({
    required this.categories,
    required this.categoryIcons,
    required this.onSeeAll,
    super.key,
  });

  final List<CategorySpend> categories;
  final Map<String, String?> categoryIcons;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final largest = categories.first.spentMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Top categories',
          action: 'See all',
          onActionTap: onSeeAll,
        ),
        AppCard(
          child: Column(
            children: [
              for (final (index, category) in categories.indexed) ...[
                if (index > 0) const SizedBox(height: Space.x2),
                Row(
                  children: [
                    CategoryAvatar(
                      iconKey: categoryIcons[category.categoryId],
                      size: 32,
                    ),
                    const SizedBox(width: Space.x1),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.rowTitle(
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Space.x1),
                              MoneyText(category.spentMinor, size: MoneySize.meta),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ProgressMeter(
                            value: largest == 0
                                ? 0
                                : category.spentMinor / largest,
                            height: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    required this.transactions,
    required this.categoryIcons,
    required this.onSeeAll,
    required this.onOpenTransaction,
    super.key,
  });

  final List<Transaction> transactions;
  final Map<String, String?> categoryIcons;
  final VoidCallback onSeeAll;
  final ValueChanged<Transaction> onOpenTransaction;

  static final _timeFormat = DateFormat('d MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();
    final money = Theme.of(context).extension<MoneyColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent activity',
          action: 'See all',
          onActionTap: onSeeAll,
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Space.x1),
          child: Column(
            children: [
              for (final transaction in transactions)
                AppListRow(
                  leading: CategoryAvatar(
                    iconKey: categoryIcons[transaction.categoryId],
                    size: 36,
                  ),
                  title: Text(
                    transaction.merchant?.isNotEmpty ?? false
                        ? transaction.merchant!
                        : 'Unknown',
                  ),
                  subtitle: Text(
                    _subtitleFor(transaction),
                    style: transaction.status == TxStatus.confirmed
                        ? null
                        // An entry the app is unsure of is marked in
                        // the review colour and named in words — it
                        // still counts toward the totals above, so
                        // silence here would overstate confidence.
                        : AppTypography.metadata(color: money.review),
                  ),
                  trailing: MoneyText.signed(
                    transaction.amountMinor,
                    isInflow: transaction.direction == TxDirection.credit,
                  ),
                  onTap: () => onOpenTransaction(transaction),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _subtitleFor(Transaction transaction) {
    final time = _timeFormat.format(transaction.transactedAt.toLocal());
    return switch (transaction.status) {
      TxStatus.confirmed => time,
      TxStatus.needsReview => '$time · needs a detail',
      TxStatus.duplicateSuspect => '$time · possible duplicate',
      TxStatus.planned => '$time · planned',
    };
  }
}

/// Prompts a trip to the Review Inbox when something is waiting.
/// Absent entirely once the inbox is empty — there is nothing to nag
/// the user about.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({required this.count, required this.onTap, super.key});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AppIcon(AppIcons.inbox, color: colors.secondary),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1 ? '1 entry needs you' : '$count entries need you',
                  style: AppTypography.rowTitle(color: colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Duplicates, missing details, and messages we could '
                  'not read',
                  style: AppTypography.metadata(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x1),
          AppIcon(
            AppIcons.chevronRight,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Entry point to the assistant, with a few openers so the field is
/// not a blank prompt. Previously a single unlabelled chip in a row of
/// three, which is why nobody found it.
class AssistantPromptCard extends StatelessWidget {
  const AssistantPromptCard({required this.onAsk, super.key});

  /// Called with the tapped suggestion, or null for a blank start.
  final ValueChanged<String?> onAsk;

  static const _suggestions = [
    'Where did I spend most?',
    "What's left this period?",
    'How can I save more?',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => onAsk(null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.assistant, size: 20, color: colors.secondary),
              const SizedBox(width: Space.x1),
              Expanded(
                child: Text(
                  'Ask about your money',
                  style: AppTypography.rowTitle(color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x1),
          Wrap(
            spacing: Space.x1,
            runSpacing: Space.x1,
            children: [
              for (final suggestion in _suggestions)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () => onAsk(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown on a first launch, before anything has been captured.
class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({required this.onAddTransaction, super.key});

  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.emptyActivity,
      title: 'Nothing captured yet',
      message: 'Messages from your bank and mobile money land here on '
          'their own. Add one by hand to get started.',
      actionLabel: 'Add a transaction',
      onAction: onAddTransaction,
    );
  }
}
