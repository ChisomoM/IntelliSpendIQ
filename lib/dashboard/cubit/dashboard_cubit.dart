import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/transaction.dart';

part 'dashboard_state.dart';

/// At-a-glance numbers for the Home tab: this budget period's income
/// vs. confirmed spend, the biggest categories, the most recent
/// activity, and how much is waiting in the Review Inbox.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required TransactionRepository transactions,
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required RawCaptureRepository rawCaptures,
    BudgetPeriod? initialPeriod,
  }) : _transactions = transactions,
       _categories = categories,
       _budgetPeriods = budgetPeriods,
       _rawCaptures = rawCaptures,
       super(DashboardState(budgetPeriod: initialPeriod));

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final RawCaptureRepository _rawCaptures;
  StreamSubscription<List<Category>>? _categoriesSubscription;
  StreamSubscription<List<CategorySpend>>? _categorySpendSubscription;
  StreamSubscription<List<Transaction>>? _recentSubscription;
  StreamSubscription<int>? _reviewSubscription;
  StreamSubscription<int>? _failedSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: DashboardStatus.loading));
    final period =
        state.budgetPeriod ??
        await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    emit(state.copyWith(budgetPeriod: period));

    await _categoriesSubscription?.cancel();
    _categoriesSubscription = _categories.watchAll().listen(_onCategories);

    await _categorySpendSubscription?.cancel();
    _categorySpendSubscription = _transactions
        .watchSpendByCategoryInRange(from: period.startAt, to: period.endAt)
        .listen(_onCategorySpend);

    await _recentSubscription?.cancel();
    _recentSubscription = _transactions
        .watchRecent(limit: 5)
        .listen(
          (rows) => emit(
            state.copyWith(
              status: DashboardStatus.loaded,
              recentTransactions: rows,
            ),
          ),
        );

    await _reviewSubscription?.cancel();
    _reviewSubscription = _transactions.watchReviewCount().listen(
      (count) => emit(
        state.copyWith(status: DashboardStatus.loaded, needsReviewCount: count),
      ),
    );

    await _failedSubscription?.cancel();
    _failedSubscription = _rawCaptures.watchFailedCount().listen(
      (count) => emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          failedCaptureCount: count,
        ),
      ),
    );
  }

  Future<void> _onCategories(List<Category> categories) async {
    final period = state.budgetPeriod;
    if (period == null) return;

    final periodAmounts = {
      for (final b in await _budgetPeriods.categoryBudgetsFor(period.id))
        b.categoryId: b.amountMinor,
    };
    final incomeCategories = categories
        .where((c) => c.isIncome && c.parentId == null)
        .map(
          (c) => Category(
            id: c.id,
            name: c.name,
            icon: c.icon,
            color: c.color,
            parentId: c.parentId,
            isSystem: c.isSystem,
            sortOrder: c.sortOrder,
            type: c.type,
            budgetedAmountMinor: periodAmounts[c.id] ?? c.budgetedAmountMinor,
          ),
        )
        .where((c) => c.hasBudget)
        .toList();

    final totalSpent = await _transactions.totalSpentInRange(
      from: period.startAt,
      to: period.endAt,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        status: DashboardStatus.loaded,
        incomeCategories: incomeCategories,
        totalSpent: totalSpent,
      ),
    );
  }

  Future<void> _onCategorySpend(List<CategorySpend> rows) async {
    final period = state.budgetPeriod;
    if (period == null) return;
    final totalSpent = await _transactions.totalSpentInRange(
      from: period.startAt,
      to: period.endAt,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        status: DashboardStatus.loaded,
        topCategories: rows.take(3).toList(),
        totalSpent: totalSpent,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _categoriesSubscription?.cancel();
    await _categorySpendSubscription?.cancel();
    await _recentSubscription?.cancel();
    await _reviewSubscription?.cancel();
    await _failedSubscription?.cancel();
    return super.close();
  }
}
