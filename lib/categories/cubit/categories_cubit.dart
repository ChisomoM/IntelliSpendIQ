import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

part 'categories_state.dart';

/// Lets the user add, rename, and remove spending categories beyond
/// the ten seeded on first launch.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._categories) : super(const CategoriesState());

  final CategoryRepository _categories;
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
    return _categories.create(
      trimmed,
      icon: _trimIcon(icon),
      parentId: parentId,
      type: type,
      budgetedAmountMinor: budgetedAmountMinor,
    );
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
