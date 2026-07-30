import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/overall_budget_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';

part 'budgets_state.dart';

/// Overall monthly budget and category-level budget envelopes,
/// tracked against confirmed spend. Categories are the budget line —
/// there is no separate per-category row, so editing a category's
/// budget (via the Categories feature) is what updates the envelope
/// this cubit shows. All arithmetic is local SQL.
class BudgetsCubit extends Cubit<BudgetsState> {
  BudgetsCubit({
    required CategoryRepository categories,
    required OverallBudgetRepository overallBudgets,
    required TransactionRepository transactions,
    String? period,
  }) : _categories = categories,
       _overallBudgets = overallBudgets,
       _transactions = transactions,
       super(BudgetsState(period: period ?? Iso.monthKey(DateTime.now())));

  final CategoryRepository _categories;
  final OverallBudgetRepository _overallBudgets;
  final TransactionRepository _transactions;
  StreamSubscription<List<Category>>? _subscription;
  StreamSubscription<OverallBudget?>? _overallSubscription;

  /// Fire-and-forget entry point for widget construction.
  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: BudgetsStatus.loading));
    await _overallBudgets.carryOverInto(state.period);

    await _subscription?.cancel();
    _subscription = _categories.watchAll().listen(_onCategories);

    await _overallSubscription?.cancel();
    _overallSubscription = _overallBudgets
        .watchForPeriod(state.period)
        .listen(_onOverallBudget);
  }

  Future<void> _onCategories(List<Category> categories) async {
    final spent = <String, int>{};
    for (final category in categories) {
      if (!category.isExpense || !category.hasBudget) continue;
      spent[category.id] = await _transactions.spentForCategory(
        category.id,
        state.period,
      );
    }
    final totalSpent = await _transactions.totalSpent(state.period);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        categories: categories,
        spentByCategory: spent,
        totalSpent: totalSpent,
      ),
    );
  }

  Future<void> _onOverallBudget(OverallBudget? overallBudget) async {
    final totalSpent = await _transactions.totalSpent(state.period);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        overallBudget: overallBudget,
        clearOverallBudget: overallBudget == null,
        totalSpent: totalSpent,
      ),
    );
  }

  Future<void> setOverallBudget(String amount) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: 'Enter a total budget, e.g. 5000',
        ),
      );
      return;
    }
    await _overallBudgets.upsert(
      period: state.period,
      amountMinor: amountMinor,
    );
  }

  Future<void> deleteOverallBudget() async {
    final id = state.overallBudget?.id;
    if (id == null) return;
    await _overallBudgets.delete(id);
  }

  /// Moves budgeted amount from one category to another. Emits
  /// [BudgetsStatus.invalid] if the source doesn't have enough
  /// budgeted, or either category doesn't exist.
  Future<void> transferBudget({
    required String fromCategoryId,
    required String toCategoryId,
    required String amount,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: 'Enter an amount to transfer, e.g. 200',
        ),
      );
      return;
    }
    final moved = await _categories.transferBudget(
      fromCategoryId: fromCategoryId,
      toCategoryId: toCategoryId,
      amountMinor: amountMinor,
    );
    if (!moved) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: "That category doesn't have that much budgeted",
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _overallSubscription?.cancel();
    return super.close();
  }
}
