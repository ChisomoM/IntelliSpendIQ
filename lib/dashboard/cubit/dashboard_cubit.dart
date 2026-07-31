import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intl/intl.dart';

part 'dashboard_state.dart';

/// At-a-glance numbers for the Home tab: what every account holds,
/// this budget period's spend against its plan, the biggest
/// categories, the most recent activity, and how much is waiting in
/// the Review Inbox.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required TransactionRepository transactions,
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required RawCaptureRepository rawCaptures,
    required AccountRepository accounts,
    BudgetPeriod? initialPeriod,
  }) : _transactions = transactions,
       _categories = categories,
       _budgetPeriods = budgetPeriods,
       _rawCaptures = rawCaptures,
       _accounts = accounts,
       super(DashboardState(budgetPeriod: initialPeriod));

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final RawCaptureRepository _rawCaptures;
  final AccountRepository _accounts;
  StreamSubscription<List<Category>>? _categoriesSubscription;
  StreamSubscription<List<CategorySpend>>? _categorySpendSubscription;
  StreamSubscription<List<Transaction>>? _recentSubscription;
  StreamSubscription<int>? _reviewSubscription;
  StreamSubscription<int>? _failedSubscription;
  StreamSubscription<BudgetPeriod?>? _periodSubscription;
  StreamSubscription<List<Account>>? _accountsSubscription;
  StreamSubscription<Map<String, int>>? _balanceSubscription;

  /// How many categories the Top categories card shows.
  static const _topCategoryLimit = 4;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: DashboardStatus.loading));
    final period =
        state.budgetPeriod ??
        await _budgetPeriods.ensurePeriodContaining(DateTime.now());

    // Accounts and the review counts are not period-scoped, so they
    // subscribe once here rather than being torn down and rebuilt on
    // every period change in [_subscribeToPeriod].
    await _accountsSubscription?.cancel();
    _accountsSubscription = _accounts.watchAll().listen(
      (rows) =>
          emit(state.copyWith(status: DashboardStatus.loaded, accounts: rows)),
    );

    await _balanceSubscription?.cancel();
    _balanceSubscription = _accounts.watchComputedBalances().listen(
      (balances) => emit(state.copyWith(accountBalances: balances)),
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

    await _subscribeToPeriod(period);
  }

  /// Walks to another budget period. Totals are cleared before the new
  /// subscriptions land so the previous period's figures never show
  /// briefly under the new period's label.
  void shiftPeriod(int delta) => unawaited(_shiftPeriod(delta));

  Future<void> _shiftPeriod(int delta) async {
    final current =
        state.budgetPeriod ??
        await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    final next = await _budgetPeriods.shiftPeriod(current, delta);
    if (isClosed) return;
    emit(
      state.copyWith(
        budgetPeriod: next,
        status: DashboardStatus.loading,
        totalSpent: 0,
        topCategories: const [],
        incomeCategories: const [],
      ),
    );
    await _subscribeToPeriod(next);
  }

  Future<void> _subscribeToPeriod(BudgetPeriod period) async {
    // Cancel before emitting, not after: an in-flight event from the
    // previous period's subscriptions would otherwise land between the
    // emit and the cancel and put the old period back into state.
    await _periodSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    await _categorySpendSubscription?.cancel();

    emit(state.copyWith(budgetPeriod: period));

    // The overall budget is what spend is measured against, and it is
    // editable from Budgets — without watching it, a plan set on
    // another tab would not reach this screen until a reload.
    _periodSubscription = _budgetPeriods.watchPeriod(period.id).listen((row) {
      if (row == null) return;
      emit(state.copyWith(budgetPeriod: row));
    });

    _categoriesSubscription = _categories.watchAll().listen(_onCategories);

    _categorySpendSubscription = _transactions
        .watchSpendByCategoryInRange(from: period.startAt, to: period.endAt)
        .listen(_onCategorySpend);
  }

  /// True when [periodId] is still the period on screen. Both handlers
  /// below await a query before emitting, and a period shift during
  /// that await would otherwise publish the old window's totals under
  /// the new window's label.
  bool _stillCurrent(String periodId) =>
      !isClosed && state.budgetPeriod?.id == periodId;

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
    if (!_stillCurrent(period.id)) return;
    emit(
      state.copyWith(
        status: DashboardStatus.loaded,
        incomeCategories: incomeCategories,
        categoryIcons: {for (final c in categories) c.id: c.icon},
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
    if (!_stillCurrent(period.id)) return;
    emit(
      state.copyWith(
        status: DashboardStatus.loaded,
        topCategories: rows.take(_topCategoryLimit).toList(),
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
    await _periodSubscription?.cancel();
    await _accountsSubscription?.cancel();
    await _balanceSubscription?.cancel();
    return super.close();
  }
}
