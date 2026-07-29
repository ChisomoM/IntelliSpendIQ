import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

part 'reports_state.dart';

/// Monthly spend by category and account, a daily calendar view, and a
/// trailing 6-month trend — all aggregated in local SQL (plan §11).
/// No LLM narration in Phase 1 — the numbers speak for themselves.
class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._transactions, {String? period})
    : super(ReportsState(period: period ?? Iso.monthKey(DateTime.now())));

  final TransactionRepository _transactions;
  StreamSubscription<List<CategorySpend>>? _categorySubscription;
  StreamSubscription<List<AccountSpend>>? _accountSubscription;
  StreamSubscription<List<DailySpend>>? _dailySubscription;

  void load() {
    emit(state.copyWith(status: ReportsStatus.loading));
    _resubscribe();
  }

  /// Moves the report window by [delta] months.
  void shiftMonth(int delta) {
    final parts = state.period.split('-');
    final shifted = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]) + delta,
    );
    emit(
      state.copyWith(
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

  void breakdownChanged(ReportsBreakdown mode) =>
      emit(state.copyWith(breakdown: mode));

  void _resubscribe() {
    unawaited(_categorySubscription?.cancel());
    _categorySubscription = _transactions
        .watchSpendByCategory(state.period)
        .listen(
          (rows) =>
              emit(state.copyWith(status: ReportsStatus.loaded, rows: rows)),
        );

    unawaited(_accountSubscription?.cancel());
    _accountSubscription = _transactions
        .watchSpendByAccount(state.period)
        .listen(
          (rows) => emit(
            state.copyWith(status: ReportsStatus.loaded, accountRows: rows),
          ),
        );

    unawaited(_dailySubscription?.cancel());
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
