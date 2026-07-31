import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';

part 'accounts_state.dart';

/// Lets the user add and remove money accounts (mobile money, bank,
/// cash, card) beyond the single default seeded on first launch, and
/// move money between them by hand.
class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this._accounts, this._transfers) : super(const AccountsState());

  final AccountRepository _accounts;
  final TransferRepository _transfers;
  StreamSubscription<List<Account>>? _subscription;
  StreamSubscription<Map<String, int>>? _balanceSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: AccountsStatus.loading));
    await _subscription?.cancel();
    await _balanceSubscription?.cancel();
    _subscription = _accounts.watchAll().listen(
      (rows) =>
          emit(state.copyWith(status: AccountsStatus.loaded, accounts: rows)),
    );
    _balanceSubscription = _accounts.watchComputedBalances().listen(
      (balances) => emit(state.copyWith(computedBalances: balances)),
    );
  }

  /// [openingBalance] is optional — an account with real history
  /// already behind it (rather than a fresh cash wallet, say) should
  /// start from what it actually holds rather than zero, since the
  /// computed balance otherwise only reflects transactions logged from
  /// this point forward.
  Future<void> add({
    required String name,
    required AccountType type,
    String? openingBalance,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: AccountsStatus.invalid,
          errorMessage: 'Give the account a name',
        ),
      );
      return;
    }

    int? openingBalanceMinor;
    final trimmedBalance = openingBalance?.trim();
    if (trimmedBalance != null && trimmedBalance.isNotEmpty) {
      openingBalanceMinor = Money.tryParseToMinor(trimmedBalance);
      if (openingBalanceMinor == null || openingBalanceMinor < 0) {
        emit(
          state.copyWith(
            status: AccountsStatus.invalid,
            errorMessage: 'Enter an opening balance like 250.00',
          ),
        );
        return;
      }
    }

    final account = await _accounts.create(name: trimmed, type: type);
    if (openingBalanceMinor != null) {
      await _accounts.updateBalance(account.id, openingBalanceMinor);
    }
  }

  /// Sets an account's balance by hand — the same field SMS parsing
  /// keeps updated automatically, informational only rather than the
  /// source of truth for spend totals, but just as editable by a user
  /// who wants it to reflect what they see in their own banking app.
  Future<void> updateBalance(String id, String amount) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor < 0) {
      emit(
        state.copyWith(
          status: AccountsStatus.invalid,
          errorMessage: 'Enter a balance like 250.00',
        ),
      );
      return;
    }
    await _accounts.updateBalance(id, amountMinor);
  }

  /// Records money moved between two of the user's own accounts —
  /// the manual counterpart to the auto-detected transfers surfaced in
  /// the Review Inbox, for moves that never generate a matching pair
  /// of transactions on their own (an ATM cash withdrawal is a bank
  /// debit SMS with nothing on the cash side to detect against).
  Future<void> recordTransfer({
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    required DateTime transactedAt,
  }) async {
    if (fromAccountId == toAccountId) {
      emit(
        state.copyWith(
          status: AccountsStatus.invalid,
          errorMessage: 'Pick two different accounts',
        ),
      );
      return;
    }
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: AccountsStatus.invalid,
          errorMessage: 'Enter an amount like 250.00',
        ),
      );
      return;
    }

    await _transfers.create(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
    );
    // Recording a transfer only touches the transfers table, which
    // this cubit doesn't otherwise watch — clear a stale invalid
    // status explicitly rather than relying on a reactive re-emit.
    emit(state.copyWith(status: AccountsStatus.loaded));
  }

  Future<void> setDefault(String id) => _accounts.setDefault(id);

  /// Refuses to delete the last account so the app is never left with
  /// nowhere to record a transaction against.
  Future<void> delete(String id) async {
    if (state.accounts.length <= 1) {
      emit(
        state.copyWith(
          status: AccountsStatus.invalid,
          errorMessage: 'You need at least one account',
        ),
      );
      return;
    }
    await _accounts.delete(id);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _balanceSubscription?.cancel();
    return super.close();
  }
}
