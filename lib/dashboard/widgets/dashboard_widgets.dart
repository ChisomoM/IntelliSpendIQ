import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/dashboard/cubit/cubit.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intl/intl.dart';

/// Greeting, review entry, settings.
///
/// The wordmark used to sit here. It has been dropped: a wordmark on
/// the screen you see every day is a landing-page habit, and the user
/// already knows which app they opened. It stays on the splash, which
/// is the one place it earns its size.
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

  String get _greeting => switch (DateTime.now().hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            _greeting,
            style: AppTypography.screenTitle(color: colors.onSurface),
          ),
        ),
        IconButton(
          onPressed: onOpenReview,
          tooltip: pendingReviewCount == 0
              ? 'Review inbox'
              : '$pendingReviewCount waiting in the review inbox',
          icon: Badge(
            // Past 99 the exact number stops mattering and the badge
            // grows wider than the icon under it.
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

/// The screen's one headline: what is left to spend, at what daily
/// pace, and whether that pace is holding.
///
/// This replaces a card that led with **spend so far**. Spend so far is
/// history — on day 2 of a period it looks alarming for no reason and
/// on day 28 it looks reassuring for no reason. What changes the next
/// decision is what is left and how long it has to last, so that is
/// what the display figure now is.
class SafeToSpendHero extends StatelessWidget {
  const SafeToSpendHero({
    required this.totalSpent,
    required this.planMinor,
    required this.planSource,
    required this.planRatio,
    required this.isOverPlan,
    required this.daysLeft,
    required this.isCurrentPeriod,
    required this.dailyAllowanceMinor,
    required this.paceVerdict,
    required this.paceDeltaMinor,
    required this.periodLabel,
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
  final int? dailyAllowanceMinor;
  final PaceVerdict paceVerdict;
  final int? paceDeltaMinor;
  final String periodLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.night800 : AppColors.ink900;
    const onSurface = AppColors.nightText;
    const onSurfaceMuted = AppColors.nightText2;
    final plan = planMinor;

    return Material(
      color: surface,
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan == null
                          ? 'SPENT · ${periodLabel.toUpperCase()}'
                          : isOverPlan
                          ? 'OVER BUDGET · ${periodLabel.toUpperCase()}'
                          : 'LEFT TO SPEND · ${periodLabel.toUpperCase()}',
                      style: AppTypography.chipOverline(color: onSurfaceMuted),
                    ),
                  ),
                  AppIcon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: onSurfaceMuted,
                  ),
                ],
              ),
              const SizedBox(height: Space.x1),
              MoneyText(
                plan == null
                    ? totalSpent
                    : (isOverPlan ? totalSpent - plan : plan - totalSpent),
                size: MoneySize.display,
                color: isOverPlan ? AppColors.outflowD : onSurface,
              ),
              if (plan != null) ...[
                const SizedBox(height: Space.x2),
                ProgressMeter(
                  value: planRatio,
                  isOver: isOverPlan,
                  onDarkSurface: true,
                ),
                const SizedBox(height: Space.x1),
                Text(
                  '${Money.display(totalSpent)} of ${Money.display(plan)} '
                  '${planSource == PlanSource.income ? 'income' : 'budget'}'
                  '${isCurrentPeriod ? ' · ${daysLeft == 1 ? '1 day' : '$daysLeft days'} left' : ''}',
                  style: AppTypography.metadata(color: onSurfaceMuted),
                ),
                if (paceVerdict != PaceVerdict.none) ...[
                  const SizedBox(height: Space.x2),
                  _PaceChip(
                    verdict: paceVerdict,
                    dailyAllowanceMinor: dailyAllowanceMinor,
                    paceDeltaMinor: paceDeltaMinor,
                  ),
                ],
              ] else ...[
                const SizedBox(height: Space.x1),
                Text(
                  'Set a budget and this becomes what you have left.',
                  style: AppTypography.metadata(color: onSurfaceMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the current pace fits the days remaining, in words first.
///
/// Sits on the dark hero, so it takes the dark-mode money colours in
/// both themes — [MoneyColors] is keyed to the *theme's* brightness and
/// cannot express a dark card inside a light theme.
class _PaceChip extends StatelessWidget {
  const _PaceChip({
    required this.verdict,
    required this.dailyAllowanceMinor,
    required this.paceDeltaMinor,
  });

  final PaceVerdict verdict;
  final int? dailyAllowanceMinor;
  final int? paceDeltaMinor;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (verdict) {
      PaceVerdict.onTrack => ('On track', AppColors.inflowD),
      PaceVerdict.slow => ('Under your pace', AppColors.inflowD),
      PaceVerdict.fast => ('Spending fast', AppColors.reviewD),
      PaceVerdict.none => ('', AppColors.nightText2),
    };

    final allowance = dailyAllowanceMinor;
    final detail = switch (verdict) {
      PaceVerdict.fast when paceDeltaMinor != null =>
        '${Money.display(paceDeltaMinor!)} ahead of an even pace',
      PaceVerdict.slow when paceDeltaMinor != null =>
        '${Money.display(-paceDeltaMinor!)} under an even pace',
      _ when allowance != null =>
        'About ${Money.display(allowance)} a day from here',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x2,
        vertical: Space.x1,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: Radii.cardRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.x1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The verdict is a word, never a colour on its own.
                Text(label, style: AppTypography.rowTitle(color: tone)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppTypography.metadata(
                      color: AppColors.nightText2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

    // A horizontal list needs a bound height, so it is derived rather
    // than fixed: a hard number clips the balance at large font scales.
    final textScaler = MediaQuery.textScalerOf(context);
    final stripHeight =
        Space.x2 * 2 + 20 + Space.x1 + 2 +
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
                        color: colors.onSurfaceVariant,
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
                      // account, or spend logged against one whose
                      // opening balance was never set — so it renders
                      // as a true minus rather than clamped to zero.
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

/// Where the period's money went: one composition bar, then the rows.
///
/// The bar is the point. Four separate progress bars, each scaled to
/// the largest category, showed four unrelated ratios and no sense of
/// the whole. A single stacked bar shows share-of-spend directly, which
/// is the actual question, and gives the category palette somewhere to
/// mean something.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    required this.categories,
    required this.categoriesById,
    required this.totalSpent,
    required this.onSeeAll,
    super.key,
  });

  final List<CategorySpend> categories;
  final Map<String, Category> categoriesById;
  final int totalSpent;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final shown = categories.fold(0, (sum, c) => sum + c.spentMinor);
    final rest = totalSpent - shown;

    CategoryHue hueFor(CategorySpend spend) => CategoryPalette.forCategory(
      categoryId: spend.categoryId,
      storedColor: categoriesById[spend.categoryId]?.color,
      brightness: brightness,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Where it went',
          action: 'See all',
          onActionTap: onSeeAll,
        ),
        AppCard(
          child: Column(
            children: [
              if (shown > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        for (final spend in categories)
                          Expanded(
                            flex: spend.spentMinor.clamp(1, 1 << 30),
                            child: Padding(
                              // A 2px gap so neighbouring fills stay
                              // separable rather than blending.
                              padding: const EdgeInsets.only(right: 2),
                              child: ColoredBox(color: hueFor(spend).series),
                            ),
                          ),
                        if (rest > 0)
                          Expanded(
                            flex: rest,
                            child: ColoredBox(
                              color: colors.surfaceContainerHigh,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Space.x2),
              for (final (index, spend) in categories.indexed) ...[
                if (index > 0) const SizedBox(height: Space.x1),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: hueFor(spend).series,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: Space.x1),
                    Expanded(
                      child: Text(
                        spend.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Text wears text colours; the swatch beside it
                        // carries the identity.
                        style: AppTypography.body(color: colors.onSurface),
                      ),
                    ),
                    const SizedBox(width: Space.x1),
                    Text(
                      totalSpent == 0
                          ? '0%'
                          : '${(spend.spentMinor / totalSpent * 100).round()}%',
                      style: AppTypography.metadata(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Space.x2),
                    MoneyText(spend.spentMinor, size: MoneySize.meta),
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
    required this.categoriesById,
    required this.onSeeAll,
    required this.onOpenTransaction,
    super.key,
  });

  final List<Transaction> transactions;
  final Map<String, Category> categoriesById;
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
          title: 'Latest',
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
                    iconKey: categoriesById[transaction.categoryId]?.icon,
                    categoryId: transaction.categoryId,
                    colorName: categoriesById[transaction.categoryId]?.color,
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
                        // An entry the app is unsure of is named in
                        // words and marked — it still counts toward the
                        // totals above, so silence would overstate
                        // confidence.
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
    final review = Theme.of(context).extension<CaptureColors>()!.uncertainField;

    return Material(
      color: review.withValues(alpha: 0.10),
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Row(
            children: [
              AppIcon(AppIcons.inbox, color: review),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 entry needs you'
                          : '$count entries need you',
                      style: AppTypography.rowTitle(color: colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Not counted in the figures above until you '
                      'confirm them',
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
        ),
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
              AppIcon(AppIcons.assistant, size: 20, color: colors.primary),
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
