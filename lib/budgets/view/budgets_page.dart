import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';
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
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: AppIcon(AppIcons.calendar),
            // Budget cycle used to sit in Settings, two levels away
            // from the periods it governs.
            tooltip: 'Budget cycle',
            onPressed: () =>
                Navigator.of(context).push<void>(BudgetCyclePage.route()),
          ),
        ],
      ),
      body: BlocBuilder<BudgetsCubit, BudgetsState>(
        builder: (context, state) {
          if (state.status == BudgetsStatus.initial ||
              state.budgetPeriod == null) {
            return const Padding(
              padding: EdgeInsets.all(Space.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeleton(width: double.infinity, height: 148),
                  SizedBox(height: Space.sectionGap),
                  LoadingSkeletonList(rowCount: 4),
                ],
              ),
            );
          }

          final cubit = context.read<BudgetsCubit>();
          final period = state.budgetPeriod!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x1,
              Space.gutter,
              _bottomInset,
            ),
            children: [
              PeriodSelector(
                label: state.periodDisplayLabel,
                onPrevious: () => cubit.shiftPeriod(-1),
                onNext: () => cubit.shiftPeriod(1),
              ),
              const SizedBox(height: Space.x1),
              BudgetHeroCard(
                plannedMinor: state.totalPlannedMinor,
                totalSpent: state.totalSpent,
                allocatedMinor: state.totalAllocatedMinor,
                daysLeft: state.daysLeft,
                isCurrentPeriod: state.isCurrentPeriod,
                overallBudget: state.overallBudget,
              ),
              const SizedBox(height: Space.sectionGap),
              IncomeSummaryCard(
                incomeCategories: state.topLevelIncomeCategories,
                periodId: period.id,
              ),
              const SizedBox(height: Space.sectionGap),
              if (state.isEmpty)
                const NoBudgetsYet()
              else ...[
                const SectionHeader(title: 'Category budgets'),
                for (final category in state.budgetedExpenseCategories)
                  ExpenseCategoryEnvelopeCard(
                    category: category,
                    spentMinor: state.spentFor(category.id),
                    periodId: period.id,
                    periodStartAt: period.startAt,
                    periodEndAt: period.endAt,
                  ),
                const SizedBox(height: Space.x1),
                // A full-width row at the end of the list it adds to,
                // rather than a bare "+" in the app bar where nothing
                // said what it would add.
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<String?>(
                    CategoryEditorPage.route(
                      initialType: CategoryType.expense,
                      periodId: period.id,
                    ),
                  ),
                  icon: AppIcon(AppIcons.add, size: 18),
                  label: const Text('Add a category budget'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
