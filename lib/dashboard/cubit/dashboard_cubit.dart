import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/transaction.dart';

part 'dashboard_state.dart';

/// At-a-glance numbers for the Home tab: this month's income vs.
/// confirmed spend, the biggest categories, the most recent activity,
/// and how much is waiting in the Review Inbox. Everything here is a
/// read of data owned elsewhere (Budgets, Activity, Review) — this
/// cubit never writes anything. It reads repositories directly rather
/// than another feature's cubit, same as every other feature in the
/// app.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required TransactionRepository transactions,
    required CategoryRepository categories,
    required RawCaptureRepository rawCaptures,
    String? period,
  }) : _transactions = transactions,
       _categories = categories,
       _rawCaptures = rawCaptures,
       super(DashboardState(period: period ?? Iso.monthKey(DateTime.now())));

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final RawCaptureRepository _rawCaptures;
  StreamSubscription<List<Category>>? _categoriesSubscription;
  StreamSubscription<List<CategorySpend>>? _categorySpendSubscription;
  StreamSubscription<List<Transaction>>? _recentSubscription;
  StreamSubscription<int>? _reviewSubscription;
  StreamSubscription<int>? _failedSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: DashboardStatus.loading));

    await _categoriesSubscription?.cancel();
    _categoriesSubscription = _categories.watchAll().listen(_onCategories);

    await _categorySpendSubscription?.cancel();
    _categorySpendSubscription = _transactions
        .watchSpendByCategory(state.period)
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
    final incomeCategories = categories
        .where((c) => c.isIncome && c.parentId == null && c.hasBudget)
        .toList();
    final totalSpent = await _transactions.totalSpent(state.period);
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
    final totalSpent = await _transactions.totalSpent(state.period);
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
