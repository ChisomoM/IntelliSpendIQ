import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';

part 'accounts_state.dart';

/// Lets the user add and remove money accounts (mobile money, bank,
/// cash, card) beyond the single default seeded on first launch.
class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this._accounts) : super(const AccountsState());

  final AccountRepository _accounts;
  StreamSubscription<List<Account>>? _subscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: AccountsStatus.loading));
    await _subscription?.cancel();
    _subscription = _accounts.watchAll().listen(
      (rows) =>
          emit(state.copyWith(status: AccountsStatus.loaded, accounts: rows)),
    );
  }

  Future<void> add({required String name, required AccountType type}) async {
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
    await _accounts.create(name: trimmed, type: type);
  }

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
    return super.close();
  }
}
