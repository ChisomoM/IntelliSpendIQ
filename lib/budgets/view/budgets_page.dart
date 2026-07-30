import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/budget_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/income_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BudgetsCubit(
        budgets: context.read<BudgetRepository>(),
        categories: context.read<CategoryRepository>(),
        transactions: context.read<TransactionRepository>(),
        income: context.read<IncomeRepository>(),
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
            tooltip: 'Set a budget',
            onPressed: () => BudgetEditorSheet.show(context),
          ),
        ],
      ),
      body: BlocBuilder<BudgetsCubit, BudgetsState>(
        builder: (context, state) {
          if (state.status == BudgetsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Month of ${state.period}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              IncomeSummaryCard(
                incomeSources: state.incomeSources,
                totalSpent: state.totalSpent,
              ),
              const SizedBox(height: 12),
              PlannedVsActualCard(
                plannedMinor: state.totalPlannedMinor,
                totalSpent: state.totalSpent,
              ),
              const SizedBox(height: 20),
              if (state.isEmpty)
                const NoBudgetsYet()
              else
                for (final budget in state.budgets)
                  BudgetCard(
                    budget: budget,
                    categoryName: state.categoryName(budget.categoryId),
                    spentMinor: state.spentFor(budget.categoryId),
                  ),
            ],
          );
        },
      ),
    );
  }
}
