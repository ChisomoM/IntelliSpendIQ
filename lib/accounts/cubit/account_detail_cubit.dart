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

part 'account_detail_state.dart';

/// One account's ledger: its live balance, every transaction posted
/// against it, and every transfer that moved money in or out of it.
class AccountDetailCubit extends Cubit<AccountDetailState> {
  AccountDetailCubit({
    required AccountRepository accounts,
    required TransactionRepository transactions,
    required TransferRepository transfers,
    required CategoryRepository categories,
    required String accountId,
  }) : _accounts = accounts,
       _transactions = transactions,
       _transfers = transfers,
       _categories = categories,
       super(AccountDetailState(accountId: accountId));

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final TransferRepository _transfers;
  final CategoryRepository _categories;

  StreamSubscription<List<Account>>? _accountSubscription;
  StreamSubscription<Map<String, int>>? _balanceSubscription;
  StreamSubscription<List<Transaction>>? _transactionSubscription;
  StreamSubscription<List<Transfer>>? _transferSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: AccountDetailStatus.loading));
    await _accountSubscription?.cancel();
    await _balanceSubscription?.cancel();
    await _transactionSubscription?.cancel();
    await _transferSubscription?.cancel();

    emit(state.copyWith(categories: await _categories.getAll()));

    _accountSubscription = _accounts.watchAll().listen(_onAccounts);
    _balanceSubscription = _accounts.watchComputedBalances().listen(
      (balances) {
        if (isClosed) return;
        emit(state.copyWith(balanceMinor: balances[state.accountId] ?? 0));
      },
    );
    _transactionSubscription = _transactions
        .watchFiltered(accountId: state.accountId)
        .listen((rows) {
          if (isClosed) return;
          emit(state.copyWith(transactions: rows));
        });
    _transferSubscription = _transfers.watchAll().listen((rows) {
      if (isClosed) return;
      emit(
        state.copyWith(
          transfers: rows
              .where(
                (transfer) =>
                    transfer.fromAccountId == state.accountId ||
                    transfer.toAccountId == state.accountId,
              )
              .toList(),
        ),
      );
    });
  }

  void _onAccounts(List<Account> accounts) {
    if (isClosed) return;
    final account = accounts.where((a) => a.id == state.accountId).firstOrNull;
    if (account == null) {
      emit(
        state.copyWith(
          status: AccountDetailStatus.notFound,
          accounts: accounts,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AccountDetailStatus.loaded,
        account: account,
        accounts: accounts,
      ),
    );
  }

  Future<void> deleteTransaction(String id) => _transactions.softDelete(id);

  Future<void> undeleteTransaction(String id) => _transactions.undelete(id);

  Future<void> deleteTransfer(String id) => _transfers.softDelete(id);

  Future<void> undeleteTransfer(String id) => _transfers.undelete(id);

  @override
  Future<void> close() async {
    await _accountSubscription?.cancel();
    await _balanceSubscription?.cancel();
    await _transactionSubscription?.cancel();
    await _transferSubscription?.cancel();
    return super.close();
  }
}
