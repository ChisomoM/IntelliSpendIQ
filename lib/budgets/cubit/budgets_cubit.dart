import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/category_budget.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';
import 'package:intl/intl.dart';

part 'budgets_state.dart';

/// Overall period budget and category envelopes, tracked against
/// confirmed spend in the selected [BudgetPeriod] window.
class BudgetsCubit extends Cubit<BudgetsState> {
  BudgetsCubit({
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required TransactionRepository transactions,
    BudgetPeriod? initialPeriod,
  }) : _categories = categories,
       _budgetPeriods = budgetPeriods,
       _transactions = transactions,
       super(BudgetsState(budgetPeriod: initialPeriod));

  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final TransactionRepository _transactions;
  StreamSubscription<List<Category>>? _categorySubscription;
  StreamSubscription<BudgetPeriod?>? _periodSubscription;
  StreamSubscription<List<CategoryBudget>>? _categoryBudgetSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: BudgetsStatus.loading));
    final period =
        state.budgetPeriod ??
        await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    await _subscribe(period);
  }

  /// Moves to the previous (-1) or next (+1) budget period.
  void shiftPeriod(int delta) => unawaited(_shiftPeriod(delta));

  Future<void> _shiftPeriod(int delta) async {
    final current =
        state.budgetPeriod ??
        await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    final next = await _budgetPeriods.shiftPeriod(current, delta);
    emit(
      state.copyWith(
        budgetPeriod: next,
        status: BudgetsStatus.loading,
        clearOverallBudget: true,
        spentByCategory: const {},
        totalSpent: 0,
        categoryBudgets: const {},
        incomeStatusByCategory: const {},
        actualIncomeMinor: 0,
        provisionalIncomeMinor: 0,
      ),
    );
    await _subscribe(next);
  }

  Future<void> _subscribe(BudgetPeriod period) async {
    await _categorySubscription?.cancel();
    await _periodSubscription?.cancel();
    await _categoryBudgetSubscription?.cancel();

    emit(state.copyWith(budgetPeriod: period));

    _periodSubscription = _budgetPeriods
        .watchPeriod(period.id)
        .listen(_onPeriod);

    _categoryBudgetSubscription = _budgetPeriods
        .watchCategoryBudgets(period.id)
        .listen(_onCategoryBudgets);

    _categorySubscription = _categories.watchAll().listen(_onCategories);
  }

  Future<void> _onPeriod(BudgetPeriod? period) async {
    if (period == null || isClosed) return;
    final totalSpent = await _transactions.totalSpentInRange(
      from: period.startAt,
      to: period.endAt,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        budgetPeriod: period,
        overallBudget: period.hasOverallBudget
            ? OverallBudget(
                id: period.id,
                period: period.id,
                amountMinor: period.overallAmountMinor!,
                carryOver: period.carryOver,
              )
            : null,
        clearOverallBudget: !period.hasOverallBudget,
        totalSpent: totalSpent,
      ),
    );
  }

  Future<void> _onCategoryBudgets(List<CategoryBudget> budgets) async {
    final map = {for (final b in budgets) b.categoryId: b.amountMinor};
    final statusMap = {
      for (final b in budgets)
        if (b.status != null) b.categoryId: b.status!,
    };
    if (isClosed) return;
    emit(state.copyWith(categoryBudgets: map, incomeStatusByCategory: statusMap));
    await _refreshSpend(state.categories);
    await _refreshIncomeTotals();
  }

  Future<void> _refreshIncomeTotals() async {
    final period = state.budgetPeriod;
    if (period == null) return;
    final totals = await _budgetPeriods.incomeTotalsForPeriod(period.id);
    if (isClosed) return;
    emit(
      state.copyWith(
        actualIncomeMinor: totals.actualMinor,
        provisionalIncomeMinor: totals.provisionalMinor,
      ),
    );
    // Keep a derived overall budget current as income changes.
    if (period.isIncomeDerived) {
      await _budgetPeriods.setIncomeDerivedBudget(
        periodId: period.id,
        source: period.budgetSource,
      );
    }
  }

  /// Marks an income category paid for the current period, backing it
  /// with a real credit transaction. [amountMinor]/[transactedAt] may
  /// differ from the category's planned figure.
  Future<void> markIncomePaid({
    required String categoryId,
    required String accountId,
    required int amountMinor,
    required DateTime transactedAt,
  }) async {
    final period = state.budgetPeriod;
    if (period == null) return;
    await _budgetPeriods.markCategoryBudgetPaid(
      periodId: period.id,
      categoryId: categoryId,
      accountId: accountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
    );
  }

  /// Marks an income category unpaid again. The transaction that had
  /// backed it, if any, is left in the ledger untouched.
  Future<void> markIncomeUnpaid(String categoryId) async {
    final period = state.budgetPeriod;
    if (period == null) return;
    await _budgetPeriods.markCategoryBudgetUnpaid(
      periodId: period.id,
      categoryId: categoryId,
    );
  }

  /// Switches how the period's overall budget is computed.
  Future<void> setBudgetSource(BudgetSource source) async {
    final period = state.budgetPeriod;
    if (period == null) return;
    if (source == BudgetSource.manual) {
      // Keep the last computed figure as the new manual starting point
      // rather than clearing it out from under the user.
      await _budgetPeriods.setOverallAmount(
        periodId: period.id,
        amountMinor: period.overallAmountMinor ?? 0,
        carryOver: period.carryOver,
      );
      return;
    }
    await _budgetPeriods.setIncomeDerivedBudget(
      periodId: period.id,
      source: source,
    );
  }

  Future<void> _onCategories(List<Category> categories) async {
    await _refreshSpend(categories);
  }

  Future<void> _refreshSpend(List<Category> categories) async {
    final period = state.budgetPeriod;
    if (period == null) return;

    final effective = _withPeriodBudgets(categories);
    final directSpent = <String, int>{};
    for (final category in effective) {
      directSpent[category.id] = await _transactions.spentForCategoryInRange(
        category.id,
        from: period.startAt,
        to: period.endAt,
      );
    }
    // A top-level category's progress includes every subcategory's
    // spend — a subcategory budget is carved out of the parent's, so
    // spending it still counts against the parent envelope. Roll up
    // for every expense parent (budgeted or not) so unbudgeted
    // categories with activity still surface on the list.
    final spent = <String, int>{};
    for (final category in effective) {
      if (!category.isExpense) continue;
      if (category.parentId != null) {
        spent[category.id] = directSpent[category.id] ?? 0;
        continue;
      }
      final childrenSpent = effective
          .where((c) => c.parentId == category.id)
          .fold<int>(0, (sum, c) => sum + (directSpent[c.id] ?? 0));
      spent[category.id] = (directSpent[category.id] ?? 0) + childrenSpent;
    }
    final totalSpent = await _transactions.totalSpentInRange(
      from: period.startAt,
      to: period.endAt,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetsStatus.loaded,
        categories: effective,
        spentByCategory: spent,
        totalSpent: totalSpent,
      ),
    );
  }

  /// Overlays this period's envelopes only — never the standing
  /// template on [Category.budgetedAmountMinor], so a previous cycle's
  /// amounts cannot leak into the view.
  List<Category> _withPeriodBudgets(List<Category> categories) {
    return [
      for (final category in categories)
        Category(
          id: category.id,
          name: category.name,
          icon: category.icon,
          color: category.color,
          parentId: category.parentId,
          isSystem: category.isSystem,
          sortOrder: category.sortOrder,
          type: category.type,
          budgetedAmountMinor: state.categoryBudgets[category.id],
        ),
    ];
  }

  Future<void> setOverallBudget(String amount) async {
    final period = state.budgetPeriod;
    if (period == null) return;
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: BudgetsStatus.invalid,
          errorMessage: 'Enter a planned budget, e.g. 5000',
        ),
      );
      return;
    }
    await _budgetPeriods.setOverallAmount(
      periodId: period.id,
      amountMinor: amountMinor,
    );
  }

  Future<void> deleteOverallBudget() async {
    final period = state.budgetPeriod;
    if (period == null) return;
    await _budgetPeriods.clearOverallAmount(period.id);
  }

  Future<void> transferBudget({
    required String fromCategoryId,
    required String toCategoryId,
    required String amount,
  }) async {
    final period = state.budgetPeriod;
    if (period == null) return;
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
    final moved = await _budgetPeriods.transferCategoryBudget(
      periodId: period.id,
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
    await _categorySubscription?.cancel();
    await _periodSubscription?.cancel();
    await _categoryBudgetSubscription?.cancel();
    return super.close();
  }
}
