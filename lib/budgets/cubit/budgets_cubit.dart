import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/income_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/monthly_income.dart';

part 'budgets_state.dart';

/// Budget CRUD plus the live over/under figures (plan §11), plus a
/// declared monthly income tracked against total confirmed spend. All
/// the arithmetic is local SQL — no LLM anywhere near the numbers.
class BudgetsCubit extends Cubit<BudgetsState> {
  BudgetsCubit({
    required BudgetRepository budgets,
    required CategoryRepository categories,
    required TransactionRepository transactions,
    required IncomeRepository income,
    String? period,
  }) : _budgets = budgets,
       _categories = categories,
       _transactions = transactions,
       _income = income,
       super(
         BudgetsState(period: period ?? Iso.monthKey(DateTime.now())),
       );

  final BudgetRepository _budgets;
  final CategoryRepository _categories;
  final TransactionRepository _transactions;
  final IncomeRepository _income;
  StreamSubscription<List<Budget>>? _subscription;
  StreamSubscription<List<MonthlyIncome>>? _incomeSubscription;

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

    await _incomeSubscription?.cancel();
    _incomeSubscription = _income
        .watchForPeriod(state.period)
        .listen(_onIncome);
  }

  Future<void> _onBudgets(List<Budget> budgets) async {
    final spent = <String, int>{};
    for (final budget in budgets) {
      spent[budget.categoryId] = await _transactions.spentForCategory(
        budget.categoryId,
        state.period,
      );
    }
    final totalSpent = await _transactions.totalSpent(state.period);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        budgets: budgets,
        spentByCategory: spent,
        totalSpent: totalSpent,
      ),
    );
  }

  Future<void> _onIncome(List<MonthlyIncome> incomeSources) async {
    final totalSpent = await _transactions.totalSpent(state.period);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        incomeSources: incomeSources,
        totalSpent: totalSpent,
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

  /// Adds a new income stream for the month, or updates the existing
  /// stream with the same [label] if there already is one.
  Future<void> addIncome(String amount, {String? label}) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: 'Enter an income amount, e.g. 5000',
        ),
      );
      return;
    }
    await _income.upsert(
      period: state.period,
      amountMinor: amountMinor,
      label: label,
    );
  }

  Future<void> updateIncome(
    String id,
    String amount, {
    String? label,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: 'Enter an income amount, e.g. 5000',
        ),
      );
      return;
    }
    await _income.updateSource(id, amountMinor: amountMinor, label: label);
  }

  Future<void> deleteIncome(String id) => _income.deleteSource(id);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _incomeSubscription?.cancel();
    return super.close();
  }
}
