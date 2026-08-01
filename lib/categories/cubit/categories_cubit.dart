import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

part 'categories_state.dart';

/// Lets the user add, rename, and remove spending categories beyond
/// the ten seeded on first launch. Planned/budget amounts are written
/// to both the standing template and the active (or [periodId]) budget
/// period when [budgetPeriods] is provided.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(
    this._categories, {
    BudgetPeriodRepository? budgetPeriods,
    String? periodId,
  }) : _budgetPeriods = budgetPeriods,
       _periodId = periodId,
       super(const CategoriesState());

  final CategoryRepository _categories;
  final BudgetPeriodRepository? _budgetPeriods;
  final String? _periodId;
  StreamSubscription<List<Category>>? _subscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: CategoriesStatus.loading));
    await _subscription?.cancel();
    _subscription = _categories.watchAll().listen(
      (rows) => emit(
        state.copyWith(status: CategoriesStatus.loaded, categories: rows),
      ),
    );
  }

  /// Returns the created category, or null if validation failed
  /// (check [CategoriesState.status] for why).
  Future<Category?> add({
    required String name,
    String? icon,
    String? parentId,
    CategoryType type = CategoryType.expense,
    String? budgetedAmount,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: 'Give the category a name',
        ),
      );
      return null;
    }
    final budgetedAmountMinor = _parseBudget(budgetedAmount);
    if (budgetedAmountMinor == null &&
        (budgetedAmount?.trim().isNotEmpty ?? false)) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: 'Enter a budget like 1500, or leave it blank',
        ),
      );
      return null;
    }
    if (parentId != null) {
      final error = _validateSubcategory(
        parentId: parentId,
        budgetedAmountMinor: budgetedAmountMinor,
      );
      if (error != null) {
        emit(state.copyWith(status: CategoriesStatus.invalid, errorMessage: error));
        return null;
      }
    }
    final created = await _categories.create(
      trimmed,
      icon: _trimIcon(icon),
      parentId: parentId,
      type: type,
      budgetedAmountMinor: budgetedAmountMinor,
    );
    await _syncPeriodAmount(created.id, budgetedAmountMinor);
    return created;
  }

  Future<void> rename(
    String id, {
    required String name,
    String? icon,
    String? parentId,
    CategoryType? type,
    String? budgetedAmount,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: 'Give the category a name',
        ),
      );
      return;
    }
    final budgetedAmountMinor = _parseBudget(budgetedAmount);
    if (budgetedAmountMinor == null &&
        (budgetedAmount?.trim().isNotEmpty ?? false)) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: 'Enter a budget like 1500, or leave it blank',
        ),
      );
      return;
    }
    if (parentId != null) {
      final error = _validateSubcategory(
        parentId: parentId,
        budgetedAmountMinor: budgetedAmountMinor,
        excludingCategoryId: id,
      );
      if (error != null) {
        emit(state.copyWith(status: CategoriesStatus.invalid, errorMessage: error));
        return;
      }
    }
    final trimmedIcon = _trimIcon(icon);
    await _categories.update(
      id,
      name: trimmed,
      icon: trimmedIcon,
      clearIcon: trimmedIcon == null,
      parentId: parentId,
      clearParent: parentId == null,
      type: type,
      budgetedAmountMinor: budgetedAmountMinor,
      clearBudget: budgetedAmountMinor == null,
    );
    await _syncPeriodAmount(id, budgetedAmountMinor);
  }

  Future<void> _syncPeriodAmount(String categoryId, int? amountMinor) async {
    final periods = _budgetPeriods;
    if (periods == null) return;
    final periodId =
        _periodId ??
        (await periods.ensurePeriodContaining(DateTime.now())).id;
    if (amountMinor == null) {
      await periods.clearCategoryBudget(
        periodId: periodId,
        categoryId: categoryId,
      );
      return;
    }
    await periods.upsertCategoryBudget(
      periodId: periodId,
      categoryId: categoryId,
      amountMinor: amountMinor,
    );
  }

  /// Enforces the two rules a subcategory must satisfy: it sits exactly
  /// one level under a top-level category (no grandchildren), and its
  /// own budget is carved out of what the parent has left after its
  /// other subcategories — it can never make the parent over-allocated.
  /// Returns an error message, or null when the subcategory is valid.
  String? _validateSubcategory({
    required String parentId,
    required int? budgetedAmountMinor,
    String? excludingCategoryId,
  }) {
    final parent = state.categories
        .where((c) => c.id == parentId)
        .firstOrNull;
    if (parent == null) return null;
    if (parent.parentId != null) {
      return "A subcategory can't itself have subcategories — pick a "
          'top-level category as the parent';
    }
    if (budgetedAmountMinor == null) return null;

    final parentBudget = parent.budgetedAmountMinor;
    if (parentBudget == null) {
      return 'Give "${parent.name}" a budget first, then split it into '
          'subcategories';
    }
    final siblingsTotal = state.categories
        .where((c) => c.parentId == parentId && c.id != excludingCategoryId)
        .fold<int>(0, (sum, c) => sum + (c.budgetedAmountMinor ?? 0));
    final available = parentBudget - siblingsTotal;
    if (budgetedAmountMinor > available) {
      return available <= 0
          ? '"${parent.name}"\'s budget is already fully split among its '
                'other subcategories'
          : 'Only ${Money.display(available)} of "${parent.name}"\'s budget '
                'is left to give a subcategory';
    }
    return null;
  }

  int? _parseBudget(String? amount) {
    final trimmed = amount?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return Money.tryParseToMinor(trimmed);
  }

  Future<void> delete(String id) async {
    final removed = await _categories.delete(id);
    if (!removed) {
      emit(
        state.copyWith(
          status: CategoriesStatus.invalid,
          errorMessage: "Default categories can't be deleted",
        ),
      );
    }
  }

  String? _trimIcon(String? icon) {
    final trimmed = icon?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
