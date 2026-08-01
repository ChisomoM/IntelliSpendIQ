import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/transactions/cubit/activity_entry.dart';

part 'transactions_state.dart';

/// Streams the transaction list, filtered by whatever search text,
/// category, account, and date range the user has set. Confirmed
/// transfers are merged in separately — they're a different entity so
/// they never count toward spend/income totals, but they still belong
/// in the Activity feed's history.
class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required TransactionRepository transactions,
    required CategoryRepository categories,
    required AccountRepository accounts,
    required TransferRepository transfers,
  }) : _transactions = transactions,
       _categories = categories,
       _accounts = accounts,
       _transfers = transfers,
       super(const TransactionsState());

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final AccountRepository _accounts;
  final TransferRepository _transfers;
  StreamSubscription<List<Transaction>>? _subscription;
  StreamSubscription<List<Transfer>>? _transferSubscription;
  Timer? _debounce;

  void subscribeUnawaited() => unawaited(subscribe());

  Future<void> subscribe() async {
    if (_subscription != null) return;
    emit(state.copyWith(status: TransactionsStatus.loading));
    emit(
      state.copyWith(
        categories: await _categories.getAll(),
        accounts: await _accounts.getAll(),
      ),
    );
    _transferSubscription = _transfers.watchAll().listen(
      (rows) => emit(state.copyWith(transfers: rows)),
    );
    _resubscribe();
  }

  /// Debounced so a resubscribe doesn't fire on every keystroke.
  void queryChanged(String query) {
    emit(state.copyWith(query: query));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _resubscribe);
  }

  void categoryFilterChanged(String? categoryId) {
    emit(
      state.copyWith(
        categoryId: categoryId,
        clearCategoryId: categoryId == null,
      ),
    );
    _resubscribe();
  }

  void accountFilterChanged(String? accountId) {
    emit(
      state.copyWith(accountId: accountId, clearAccountId: accountId == null),
    );
    _resubscribe();
  }

  /// [to] is the last day to include (inclusive) — the cubit widens it
  /// to the start of the following day before querying.
  void dateRangeChanged({DateTime? from, DateTime? to}) {
    emit(
      state.copyWith(
        dateFrom: from,
        clearDateFrom: from == null,
        dateTo: to,
        clearDateTo: to == null,
      ),
    );
    _resubscribe();
  }

  /// Money in / money out, or null for both. Filtered in state rather
  /// than in the query, so no resubscribe is needed.
  void directionFilterChanged(TxDirection? direction) {
    emit(
      state.copyWith(direction: direction, clearDirection: direction == null),
    );
  }

  void clearFilters() {
    _debounce?.cancel();
    emit(
      state.copyWith(
        query: '',
        clearCategoryId: true,
        clearAccountId: true,
        clearDateFrom: true,
        clearDateTo: true,
        clearDirection: true,
      ),
    );
    _resubscribe();
  }

  void _resubscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _transactions
        .watchFiltered(
          query: state.query,
          categoryId: state.categoryId,
          accountId: state.accountId,
          from: state.dateFrom,
          // The end date is inclusive from the user's point of view,
          // so widen the bound to the start of the following day.
          to: state.dateTo?.add(const Duration(days: 1)),
        )
        .listen(
          (rows) => emit(
            state.copyWith(
              status: TransactionsStatus.loaded,
              transactions: rows,
            ),
          ),
        );
  }

  /// Removes a transaction directly from the list — e.g. a transfer
  /// that landed as both a bank debit and a mobile money credit.
  Future<void> delete(String id) => _transactions.softDelete(id);

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _subscription?.cancel();
    await _transferSubscription?.cancel();
    return super.close();
  }
}
