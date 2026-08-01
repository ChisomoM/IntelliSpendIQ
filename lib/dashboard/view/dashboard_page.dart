import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/accounts/accounts.dart';
import 'package:intellispendiq/chat/chat.dart';
import 'package:intellispendiq/core/app_section.dart';
import 'package:intellispendiq/dashboard/cubit/cubit.dart';
import 'package:intellispendiq/dashboard/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/home/cubit/cubit.dart';
import 'package:intellispendiq/review/review.dart';
import 'package:intellispendiq/settings/settings.dart';
import 'package:intellispendiq/transactions/transactions.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(
        transactions: context.read<TransactionRepository>(),
        categories: context.read<CategoryRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        rawCaptures: context.read<RawCaptureRepository>(),
        accounts: context.read<AccountRepository>(),
      )..loadUnawaited(),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  /// Clears the bottom nav bar and the docked FAB, which the shell
  /// draws over this scroll view.
  static const _bottomInset = 96.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            final home = context.read<HomeCubit>();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x1,
                Space.gutter,
                _bottomInset,
              ),
              children: [
                DashboardHeader(
                  pendingReviewCount: state.pendingReviewCount,
                  onOpenReview: () => Navigator.of(
                    context,
                  ).push<void>(ReviewInboxPage.route()),
                  onOpenSettings: () =>
                      Navigator.of(context).push<void>(SettingsPage.route()),
                ),
                const SizedBox(height: Space.x2),
                if (state.status == DashboardStatus.initial)
                  const _DashboardLoading()
                else ...[
                  // The one number first. Everything below it is
                  // detail you go looking for, so nothing else on this
                  // screen competes with it for weight.
                  SafeToSpendHero(
                    totalSpent: state.totalSpent,
                    planMinor: state.planMinor,
                    planSource: state.planSource,
                    planRatio: state.planRatio,
                    isOverPlan: state.isOverPlan,
                    daysLeft: state.daysLeft,
                    isCurrentPeriod: state.isCurrentPeriod,
                    dailyAllowanceMinor: state.dailyAllowanceMinor,
                    paceVerdict: state.paceVerdict,
                    paceDeltaMinor: state.paceDeltaMinor,
                    periodLabel: state.periodDisplayLabel,
                    onTap: () => home.tabSelected(AppSection.budgets.tabIndex),
                  ),
                  if (state.pendingReviewCount > 0) ...[
                    const SizedBox(height: Space.x1),
                    ReviewBanner(
                      count: state.pendingReviewCount,
                      onTap: () => Navigator.of(
                        context,
                      ).push<void>(ReviewInboxPage.route()),
                    ),
                  ],
                  const SizedBox(height: Space.sectionGap),
                  AccountBalanceStrip(
                    accounts: state.accounts,
                    balances: state.accountBalances,
                    onOpenAccounts: () =>
                        Navigator.of(context).push<void>(AccountsPage.route()),
                  ),
                  if (state.accounts.isNotEmpty)
                    const SizedBox(height: Space.sectionGap),
                  CategoryBreakdownCard(
                    categories: state.topCategories,
                    categoriesById: state.categoriesById,
                    totalSpent: state.totalSpent,
                    onSeeAll: () =>
                        home.tabSelected(AppSection.reports.tabIndex),
                  ),
                  if (state.topCategories.isNotEmpty)
                    const SizedBox(height: Space.sectionGap),
                  if (state.recentTransactions.isEmpty)
                    DashboardEmptyState(
                      onAddTransaction: () => Navigator.of(
                        context,
                      ).push<void>(TransactionEntryPage.route()),
                    )
                  else
                    RecentActivityCard(
                      transactions: state.recentTransactions,
                      categoriesById: state.categoriesById,
                      onSeeAll: () =>
                          home.tabSelected(AppSection.activity.tabIndex),
                      onOpenTransaction: (transaction) => Navigator.of(
                        context,
                      ).push<void>(
                        TransactionEntryPage.route(existing: transaction),
                      ),
                    ),
                  const SizedBox(height: Space.sectionGap),
                  AssistantPromptCard(
                    onAsk: (prompt) => Navigator.of(
                      context,
                    ).push<void>(ChatPage.route(initialPrompt: prompt)),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Skeletons shaped like the cards they stand in for, rather than a
/// bare spinner over the whole page.
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shaped like what lands: the hero, then the strip, then rows.
        LoadingSkeleton(width: double.infinity, height: 188),
        SizedBox(height: Space.sectionGap),
        LoadingSkeleton(width: 168, height: 104),
        SizedBox(height: Space.sectionGap),
        LoadingSkeletonList(rowCount: 3),
      ],
    );
  }
}
