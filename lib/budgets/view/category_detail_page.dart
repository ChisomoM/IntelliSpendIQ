import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/design/design.dart';

/// One category's budget envelope: stat tiles, a spend gauge, its
/// subcategories, and moving budget to another category.
class CategoryDetailPage extends StatelessWidget {
  const CategoryDetailPage({
    required this.categoryId,
    this.periodId,
    this.periodStartAt,
    this.periodEndAt,
    super.key,
  });

  final String categoryId;
  final String? periodId;
  final String? periodStartAt;
  final String? periodEndAt;

  static Route<void> route({
    required String categoryId,
    String? periodId,
    String? periodStartAt,
    String? periodEndAt,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => CategoryDetailPage(
        categoryId: categoryId,
        periodId: periodId,
        periodStartAt: periodStartAt,
        periodEndAt: periodEndAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (fallbackFrom, fallbackTo) = Iso.monthBoundsUtc(
      Iso.monthKey(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => CategoryDetailCubit(
        categories: context.read<CategoryRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        transactions: context.read<TransactionRepository>(),
        categoryId: categoryId,
        periodId: periodId,
        periodStartAt: periodStartAt ?? fallbackFrom,
        periodEndAt: periodEndAt ?? fallbackTo,
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
            body: Padding(
              padding: EdgeInsets.all(Space.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeleton(width: double.infinity, height: 72),
                  SizedBox(height: Space.sectionGap),
                  LoadingSkeleton(width: double.infinity, height: 148),
                ],
              ),
            ),
          );
        }
        if (state.status == CategoryDetailStatus.notFound ||
            state.category == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorState(
              message: 'This category no longer exists.',
            ),
          );
        }

        final category = state.category!;
        final hasBudget = state.budgetedMinor > 0;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CategoryAvatar(
                  iconKey: category.icon,
                  categoryId: category.id,
                  colorName: category.color,
                  size: 28,
                ),
                const SizedBox(width: Space.x1),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: AppIcon(AppIcons.edit),
                tooltip: 'Edit category',
                onPressed: () => Navigator.of(
                  context,
                ).push<String?>(CategoryEditorPage.route(existing: category)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x2,
              Space.gutter,
              Space.x4,
            ),
            children: [
              CategoryStatTiles(
                budgetedMinor: state.budgetedMinor,
                spentMinor: state.spentMinor,
                remainingMinor: state.remainingMinor,
              ),
              if (hasBudget) ...[
                const SizedBox(height: Space.sectionGap),
                Center(
                  child: MoneyGauge(
                    spentMinor: state.spentMinor,
                    budgetedMinor: state.budgetedMinor,
                    arcColor: CategoryPalette.forCategory(
                      categoryId: category.id,
                      storedColor: category.color,
                      brightness: Theme.of(context).brightness,
                    ).series,
                  ),
                ),
              ],
              const SizedBox(height: Space.sectionGap),
              AppButton.secondary(
                onPressed: () => BudgetTransferSheet.show(context),
                icon: AppIcon(AppIcons.transfer, size: 18),
                label: 'Move budget to another category',
              ),
              const SizedBox(height: Space.sectionGap),
              SectionHeader(
                title: 'Subcategories',
                subtitle: state.children.isEmpty
                    ? null
                    : '${Money.display(state.totalSubcategoriesBudgetedMinor)}'
                          ' budgeted across them',
                action: state.children.isEmpty ? null : 'Add',
                onActionTap: () => _addSubcategory(context, state),
              ),
              if (state.children.isEmpty)
                EmptyState(
                  icon: AppIcons.emptyWallet,
                  title: 'No subcategories yet',
                  message: 'Break this budget down to see where inside it '
                      'the money goes.',
                  actionLabel: 'Add a subcategory',
                  onAction: () => _addSubcategory(context, state),
                )
              else
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

  void _addSubcategory(BuildContext context, CategoryDetailState state) {
    final category = state.category!;
    Navigator.of(context).push<String?>(
      CategoryEditorPage.route(
        parentId: category.id,
        initialType: category.type,
        lockParent: true,
      ),
    );
  }
}
