import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

/// One category's budget envelope: stat tiles, a spend gauge, its
/// subcategories, and moving budget to another category.
class CategoryDetailPage extends StatelessWidget {
  const CategoryDetailPage({
    required this.categoryId,
    this.period,
    super.key,
  });

  final String categoryId;
  final String? period;

  static Route<void> route({required String categoryId, String? period}) {
    return MaterialPageRoute<void>(
      builder: (_) =>
          CategoryDetailPage(categoryId: categoryId, period: period),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoryDetailCubit(
        categories: context.read<CategoryRepository>(),
        transactions: context.read<TransactionRepository>(),
        categoryId: categoryId,
        period: period ?? Iso.monthKey(DateTime.now()),
      )..loadUnawaited(),
      child: const CategoryDetailView(),
    );
  }
}

class CategoryDetailView extends StatelessWidget {
  const CategoryDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryDetailCubit, CategoryDetailState>(
      builder: (context, state) {
        if (state.status == CategoryDetailStatus.initial ||
            state.status == CategoryDetailStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == CategoryDetailStatus.notFound ||
            state.category == null) {
          return const Scaffold(
            body: Center(child: Text('Category not found')),
          );
        }

        final category = state.category!;
        return Scaffold(
          appBar: AppBar(
            title: Text(category.displayName),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => Navigator.of(
                  context,
                ).push<String?>(CategoryEditorPage.route(existing: category)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CategoryStatTiles(
                budgetedMinor: state.budgetedMinor,
                spentMinor: state.spentMinor,
                remainingMinor: state.remainingMinor,
              ),
              const SizedBox(height: 20),
              Center(
                child: BudgetGauge(
                  spentMinor: state.spentMinor,
                  budgetedMinor: state.budgetedMinor,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () => BudgetTransferSheet.show(context),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Budget Transfer'),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  title: const Text('Total subcategories budgeted'),
                  trailing: Text(
                    Money.format(state.totalSubcategoriesBudgetedMinor),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Subcategories',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Subcategory'),
                    onPressed: () => Navigator.of(context).push<String?>(
                      CategoryEditorPage.route(
                        parentId: category.id,
                        initialType: category.type,
                        lockParent: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final child in state.children)
                SubcategoryRow(
                  category: child,
                  spentMinor: state.spentFor(child.id),
                ),
            ],
          ),
        );
      },
    );
  }
}
