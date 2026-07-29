import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';

part 'transactions_state.dart';

/// Streams the recent transaction list.
class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit(this._transactions) : super(const TransactionsState());

  final TransactionRepository _transactions;
  StreamSubscription<List<TransactionRow>>? _subscription;

  void subscribe() {
    if (_subscription != null) return;
    emit(state.copyWith(status: TransactionsStatus.loading));
    _subscription = _transactions.watchRecent().listen(
      (rows) => emit(
        state.copyWith(
          status: TransactionsStatus.loaded,
          transactions: rows,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
