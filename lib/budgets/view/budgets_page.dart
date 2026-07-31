import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add category budget',
            onPressed: () => Navigator.of(context).push<String?>(
              CategoryEditorPage.route(initialType: CategoryType.expense),
            ),
          ),
        ],
      ),
      body: BlocBuilder<BudgetsCubit, BudgetsState>(
        builder: (context, state) {
          if (state.status == BudgetsStatus.initial ||
              state.budgetPeriod == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final cubit = context.read<BudgetsCubit>();
          final period = state.budgetPeriod!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous period',
                    onPressed: () => cubit.shiftPeriod(-1),
                  ),
                  Expanded(
                    child: Text(
                      state.periodLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next period',
                    onPressed: () => cubit.shiftPeriod(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              IncomeSummaryCard(
                incomeCategories: state.topLevelIncomeCategories,
                totalSpent: state.totalSpent,
                periodId: period.id,
              ),
              const SizedBox(height: 12),
              PlannedVsActualCard(
                plannedMinor: state.totalPlannedMinor,
                totalSpent: state.totalSpent,
                allocatedMinor: state.totalAllocatedMinor,
                overallBudget: state.overallBudget,
              ),
              const SizedBox(height: 20),
              if (state.isEmpty)
                const NoBudgetsYet()
              else
                for (final category in state.budgetedExpenseCategories)
                  ExpenseCategoryEnvelopeCard(
                    category: category,
                    spentMinor: state.spentFor(category.id),
                    periodId: period.id,
                    periodStartAt: period.startAt,
                    periodEndAt: period.endAt,
                  ),
            ],
          );
        },
      ),
    );
  }
}
