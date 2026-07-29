import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

part 'reports_state.dart';

/// Monthly spend by category, aggregated in local SQL (plan §11).
/// No LLM narration in Phase 1 — the numbers speak for themselves.
class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._transactions, {String? period})
    : super(ReportsState(period: period ?? Iso.monthKey(DateTime.now())));

  final TransactionRepository _transactions;
  StreamSubscription<List<CategorySpend>>? _subscription;

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
      ),
    );
    _resubscribe();
  }

  void _resubscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _transactions
        .watchSpendByCategory(state.period)
        .listen(
          (rows) => emit(
            state.copyWith(status: ReportsStatus.loaded, rows: rows),
          ),
        );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
