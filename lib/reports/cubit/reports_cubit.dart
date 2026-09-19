import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intl/intl.dart';

part 'reports_state.dart';

/// Monthly (or cycle) spend by category and account, a daily calendar
/// view, and a trailing 6-month trend — all aggregated in local SQL
/// (plan §11). No LLM narration in Phase 1 — the numbers speak for
/// themselves.
class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(
    this._transactions, {
    BudgetPeriodRepository? budgetPeriods,
    String? period,
  }) : _budgetPeriods = budgetPeriods,
       super(ReportsState(period: period ?? Iso.monthKey(DateTime.now())));

  final TransactionRepository _transactions;
  final BudgetPeriodRepository? _budgetPeriods;
  StreamSubscription<List<CategorySpend>>? _categorySubscription;
  StreamSubscription<List<AccountSpend>>? _accountSubscription;
  StreamSubscription<List<DailySpend>>? _dailySubscription;

  /// Whether cycle mode is available at all (needs a period repository).
  bool get supportsCycleMode => _budgetPeriods != null;

  void load() {
    emit(state.copyWith(status: ReportsStatus.loading));
    _resubscribe();
  }

  /// Moves the report window by [delta] months. Month mode only.
  void shiftMonth(int delta) {
    final parts = state.period.split('-');
    final shifted = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]) + delta,
    );
    emit(
      state.copyWith(
        mode: ReportsMode.month,
        period: Iso.monthKey(shifted),
        status: ReportsStatus.loading,
        rows: const [],
        accountRows: const [],
        dailySpend: const [],
        monthTrend: const [],
      ),
    );
    _resubscribe();
  }

  /// Moves the report window by [delta] budget cycles. Cycle mode only.
  Future<void> shiftCycle(int delta) async {
    final periods = _budgetPeriods;
    if (periods == null) return;
    final current =
        state.cyclePeriod ?? await periods.ensurePeriodContaining(DateTime.now());
    final next = await periods.shiftPeriod(current, delta);
    emit(
      state.copyWith(
        mode: ReportsMode.cycle,
        cyclePeriod: next,
        status: ReportsStatus.loading,
        rows: const [],
        accountRows: const [],
      ),
    );
    _resubscribe();
  }

  /// Switches between month and cycle windowing. Cycle mode needs a
  /// [BudgetPeriodRepository] — a no-op without one.
  Future<void> setMode(ReportsMode mode) async {
    if (mode == state.mode) return;
    if (mode == ReportsMode.cycle) {
      final periods = _budgetPeriods;
      if (periods == null) return;
      final period =
          state.cyclePeriod ??
          await periods.ensurePeriodContaining(DateTime.now());
      emit(
        state.copyWith(
          mode: ReportsMode.cycle,
          cyclePeriod: period,
          status: ReportsStatus.loading,
        ),
      );
    } else {
      emit(state.copyWith(mode: ReportsMode.month, status: ReportsStatus.loading));
    }
    _resubscribe();
  }

  void breakdownChanged(ReportsBreakdown mode) =>
      emit(state.copyWith(breakdown: mode));

  void _resubscribe() {
    unawaited(_categorySubscription?.cancel());
    unawaited(_accountSubscription?.cancel());
    unawaited(_dailySubscription?.cancel());

    if (state.mode == ReportsMode.cycle) {
      final periodId = state.cyclePeriod?.id;
      if (periodId == null) return;
      _categorySubscription = _transactions
          .watchSpendByCategoryForPeriod(periodId)
          .listen(
            (rows) =>
                emit(state.copyWith(status: ReportsStatus.loaded, rows: rows)),
          );
      _accountSubscription = _transactions
          .watchSpendByAccountForPeriod(periodId)
          .listen(
            (rows) => emit(
              state.copyWith(status: ReportsStatus.loaded, accountRows: rows),
            ),
          );
      // Day-by-day heatmap and the trailing trend are calendar-month
      // shaped and don't apply to an arbitrary cycle window.
      emit(
        state.copyWith(
          dailySpend: const [],
          monthTrend: const [],
        ),
      );
      return;
    }

    _categorySubscription = _transactions
        .watchSpendByCategory(state.period)
        .listen(
          (rows) =>
              emit(state.copyWith(status: ReportsStatus.loaded, rows: rows)),
        );

    _accountSubscription = _transactions
        .watchSpendByAccount(state.period)
        .listen(
          (rows) => emit(
            state.copyWith(status: ReportsStatus.loaded, accountRows: rows),
          ),
        );

    _dailySubscription = _transactions
        .watchDailySpend(state.period)
        .listen(
          (rows) => emit(
            state.copyWith(status: ReportsStatus.loaded, dailySpend: rows),
          ),
        );

    unawaited(_loadTrend());
  }

  Future<void> _loadTrend() async {
    final trend = await _transactions.spendTrend(state.period);
    if (isClosed) return;
    emit(state.copyWith(status: ReportsStatus.loaded, monthTrend: trend));
  }

  @override
  Future<void> close() async {
    await _categorySubscription?.cancel();
    await _accountSubscription?.cancel();
    await _dailySubscription?.cancel();
    return super.close();
  }
}
