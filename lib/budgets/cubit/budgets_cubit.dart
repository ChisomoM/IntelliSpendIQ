import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget.dart';
import 'package:intellispendiq/domain/models/category.dart';

part 'budgets_state.dart';

/// Budget CRUD plus the live over/under figures (plan §11). All the
/// arithmetic is local SQL — no LLM anywhere near the numbers.
class BudgetsCubit extends Cubit<BudgetsState> {
  BudgetsCubit({
    required BudgetRepository budgets,
    required CategoryRepository categories,
    required TransactionRepository transactions,
    String? period,
  }) : _budgets = budgets,
       _categories = categories,
       _transactions = transactions,
       super(
         BudgetsState(period: period ?? Iso.monthKey(DateTime.now())),
       );

  final BudgetRepository _budgets;
  final CategoryRepository _categories;
  final TransactionRepository _transactions;
  StreamSubscription<List<Budget>>? _subscription;

  /// Fire-and-forget entry point for widget construction.
  void loadUnawaited() => unawaited(load());

  /// Carries last month's limits forward as editable defaults, then
  /// starts watching this month.
  Future<void> load() async {
    emit(state.copyWith(status: BudgetsStatus.loading));
    await _budgets.carryOverInto(state.period);
    emit(state.copyWith(categories: await _categories.getAll()));

    await _subscription?.cancel();
    _subscription = _budgets.watchForPeriod(state.period).listen(_onBudgets);
  }

  Future<void> _onBudgets(List<Budget> budgets) async {
    final spent = <String, int>{};
    for (final budget in budgets) {
      spent[budget.categoryId] = await _transactions.spentForCategory(
        budget.categoryId,
        state.period,
      );
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        budgets: budgets,
        spentByCategory: spent,
      ),
    );
  }

  Future<void> upsert({
    required String categoryId,
    required String amount,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: 'Enter a monthly limit like 1500',
        ),
      );
      return;
    }
    await _budgets.upsert(
      categoryId: categoryId,
      period: state.period,
      amountMinor: amountMinor,
    );
  }

  Future<void> delete(String budgetId) => _budgets.delete(budgetId);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
