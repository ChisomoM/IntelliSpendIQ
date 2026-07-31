import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/overall_budget_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/ui/ui.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BudgetsCubit(
        categories: context.read<CategoryRepository>(),
        overallBudgets: context.read<OverallBudgetRepository>(),
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
    // The shell owns the Scaffold and the app bar; "add a budget" moves
    // into the body next to the envelopes it adds to.
    return BlocBuilder<BudgetsCubit, BudgetsState>(
      builder: (context, state) {
        if (state.status == BudgetsStatus.initial) {
          return const LoadingState();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Month of ${state.period}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Budget'),
                  onPressed: () => Navigator.of(context).push<String?>(
                    CategoryEditorPage.route(
                      initialType: CategoryType.expense,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            IncomeSummaryCard(
              incomeCategories: state.budgetedIncomeCategories,
              totalSpent: state.totalSpent,
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
                ),
          ],
        );
      },
    );
  }
}
