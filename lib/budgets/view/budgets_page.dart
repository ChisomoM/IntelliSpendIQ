import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/view/budget_plan_page.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/chat/chat.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/settings/view/budget_cycle_page.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BudgetsCubit(
        categories: context.read<CategoryRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        transactions: context.read<TransactionRepository>(),
      )..loadUnawaited(),
      child: const BudgetsView(),
    );
  }
}

class BudgetsView extends StatelessWidget {
  const BudgetsView({super.key});

  /// Clears the bottom nav bar and the docked FAB.
  static const _bottomInset = 96.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No app bar: the title lives in the scroll so it can be
      // display-sized and carry a subtitle, and the period control sits
      // directly under it instead of below a chrome bar.
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<BudgetsCubit, BudgetsState>(
          builder: (context, state) {
            final cubit = context.read<BudgetsCubit>();
            final period = state.budgetPeriod;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x1,
                Space.gutter,
                _bottomInset,
              ),
              children: [
                BudgetsHeader(
                  onAddCategory: () => _addCategory(context, period?.id),
                ),
                const SizedBox(height: Space.x2),
                if (state.status == BudgetsStatus.initial || period == null)
                  const _BudgetsLoading()
                else ...[
                  PeriodPill(
                    label: state.periodDisplayLabel,
                    onPrevious: () => cubit.shiftPeriod(-1),
                    onNext: () => cubit.shiftPeriod(1),
                  ),
                  const SizedBox(height: Space.x2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SpendModeToggle(
                      includePlanned: state.includePlanned,
                      onChanged: (value) =>
                          cubit.setIncludePlanned(value: value),
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  BudgetHeroCard(
                    plannedMinor: state.totalPlannedMinor,
                    totalSpent: state.totalSpent,
                    allocatedMinor: state.totalAllocatedMinor,
                    daysLeft: state.daysLeft,
                    isCurrentPeriod: state.isCurrentPeriod,
                    overallBudget: state.overallBudget,
                    includePlanned: state.includePlanned,
                    onViewPlan: () => Navigator.of(context).push<void>(
                      BudgetPlanPage.route(
                        periodLabel: state.periodDisplayLabel,
                        plannedIncomeMinor: state.provisionalIncomeMinor,
                        plannedExpenseMinor: state.totalAllocatedMinor,
                        expenseCategories: state.budgetedExpenseCategories,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.sectionGap),
                  IncomeSummaryCard(
                    incomeCategories: state.topLevelIncomeCategories,
                    statusByCategory: state.incomeStatusByCategory,
                    actualMinor: state.actualIncomeMinor,
                    provisionalMinor: state.provisionalIncomeMinor,
                    periodId: period.id,
                    onTapRow: (category, current) =>
                        _toggleIncomePaid(context, category, current),
                  ),
                  const SizedBox(height: Space.sectionGap),
                  if (state.isEmpty)
                    const NoBudgetsYet()
                  else ...[
                    SectionHeader(
                      title: 'Category budgets',
                      subtitle: state.includePlanned
                          ? 'Including planned (unpaid) spend'
                          : null,
                      action: 'Cycle',
                      onActionTap: () => Navigator.of(
                        context,
                      ).push<void>(BudgetCyclePage.route()),
                    ),
                    for (final category in state.visibleExpenseCategories)
                      ExpenseCategoryEnvelopeCard(
                        category: category,
                        spentMinor: state.spentFor(category.id),
                        periodId: period.id,
                        periodStartAt: period.startAt,
                        periodEndAt: period.endAt,
                      ),
                    AddCategoryCard(
                      onTap: () => _addCategory(context, period.id),
                    ),
                  ],
                  if (state.insight != null) ...[
                    const SizedBox(height: Space.sectionGap),
                    BudgetInsightCard(
                      message: state.insight!,
                      onOpen: () => Navigator.of(context).push<void>(
                        ChatPage.route(
                          initialPrompt: 'How are my budgets doing?',
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _addCategory(BuildContext context, String? periodId) {
    Navigator.of(context).push<String?>(
      CategoryEditorPage.route(
        initialType: CategoryType.expense,
        periodId: periodId,
      ),
    );
  }

  Future<void> _toggleIncomePaid(
    BuildContext context,
    Category category,
    IncomeStatus? current,
  ) async {
    final cubit = context.read<BudgetsCubit>();
    if (current == IncomeStatus.paid) {
      await cubit.markIncomeUnpaid(category.id);
      return;
    }
    final accountRepository = context.read<AccountRepository>();
    final accounts = await accountRepository.getAll();
    final defaultAccount = await accountRepository.getDefault();
    if (!context.mounted) return;
    final result = await showMarkIncomePaidSheet(
      context,
      category: category,
      accounts: accounts,
      defaultAccountId: defaultAccount.id,
    );
    if (result == null) return;
    await cubit.markIncomePaid(
      categoryId: category.id,
      accountId: result.accountId,
      amountMinor: result.amountMinor,
      transactedAt: result.transactedAt,
    );
  }
}

class _BudgetsLoading extends StatelessWidget {
  const _BudgetsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoadingSkeleton(width: double.infinity, height: 48),
        SizedBox(height: Space.x2),
        LoadingSkeleton(width: double.infinity, height: 196),
        SizedBox(height: Space.sectionGap),
        LoadingSkeletonList(rowCount: 4),
      ],
    );
  }
}
