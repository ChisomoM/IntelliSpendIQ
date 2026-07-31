import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';

part 'category_detail_state.dart';

/// One category's budget envelope: itself, its subcategories, and how
/// much of each has been spent this period — plus moving budget
/// between categories.
class CategoryDetailCubit extends Cubit<CategoryDetailState> {
  CategoryDetailCubit({
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required TransactionRepository transactions,
    required String categoryId,
    required String periodStartAt,
    required String periodEndAt,
    String? periodId,
  }) : _categories = categories,
       _budgetPeriods = budgetPeriods,
       _transactions = transactions,
       super(
         CategoryDetailState(
           categoryId: categoryId,
           periodId: periodId,
           periodStartAt: periodStartAt,
           periodEndAt: periodEndAt,
         ),
       );

  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final TransactionRepository _transactions;
  StreamSubscription<List<Category>>? _subscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: CategoryDetailStatus.loading));
    await _subscription?.cancel();
    _subscription = _categories.watchAll().listen(_onCategories);
  }

  Future<void> _onCategories(List<Category> categories) async {
    final self = categories.where((c) => c.id == state.categoryId).firstOrNull;
    if (self == null) {
      if (!isClosed) {
        emit(state.copyWith(status: CategoryDetailStatus.notFound));
      }
      return;
    }
    final children = categories
        .where((c) => c.parentId == state.categoryId)
        .toList();

    final periodAmounts = state.periodId == null
        ? const <String, int>{}
        : {
            for (final b in await _budgetPeriods.categoryBudgetsFor(
              state.periodId!,
            ))
              b.categoryId: b.amountMinor,
          };

    Category overlay(Category category) => Category(
      id: category.id,
      name: category.name,
      icon: category.icon,
      color: category.color,
      parentId: category.parentId,
      isSystem: category.isSystem,
      sortOrder: category.sortOrder,
      type: category.type,
      budgetedAmountMinor:
          periodAmounts[category.id] ?? category.budgetedAmountMinor,
    );

    final spentMinor = await _transactions.spentForCategoryInRange(
      state.categoryId,
      from: state.periodStartAt,
      to: state.periodEndAt,
    );
    final spentByChild = <String, int>{};
    for (final child in children) {
      spentByChild[child.id] = await _transactions.spentForCategoryInRange(
        child.id,
        from: state.periodStartAt,
        to: state.periodEndAt,
      );
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: CategoryDetailStatus.loaded,
        category: overlay(self),
        allCategories: categories.map(overlay).toList(),
        children: children.map(overlay).toList(),
        spentMinor: spentMinor,
        spentByChild: spentByChild,
      ),
    );
  }

  /// Moves budget from this category to [toCategoryId].
  Future<void> transferTo(String toCategoryId, String amount) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: CategoryDetailStatus.invalid,
          errorMessage: 'Enter an amount to transfer, e.g. 200',
        ),
      );
      return;
    }

    final moved = state.periodId == null
        ? await _categories.transferBudget(
            fromCategoryId: state.categoryId,
            toCategoryId: toCategoryId,
            amountMinor: amountMinor,
          )
        : await _budgetPeriods.transferCategoryBudget(
            periodId: state.periodId!,
            fromCategoryId: state.categoryId,
            toCategoryId: toCategoryId,
            amountMinor: amountMinor,
          );
    if (!moved) {
      emit(
        state.copyWith(
          status: CategoryDetailStatus.invalid,
          errorMessage: "This category doesn't have that much budgeted",
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
