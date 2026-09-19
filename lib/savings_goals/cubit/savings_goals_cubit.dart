import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/savings_goal_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';

part 'savings_goals_state.dart';

/// Every savings goal, its live saved total, and the accounts a
/// contribution sheet can pick from.
class SavingsGoalsCubit extends Cubit<SavingsGoalsState> {
  SavingsGoalsCubit(this._goals, this._accounts) : super(const SavingsGoalsState());

  final SavingsGoalRepository _goals;
  final AccountRepository _accounts;

  StreamSubscription<List<SavingsGoal>>? _goalsSubscription;
  StreamSubscription<Map<String, int>>? _savedSubscription;
  StreamSubscription<List<Account>>? _accountsSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: SavingsGoalsStatus.loading));
    await _goalsSubscription?.cancel();
    await _savedSubscription?.cancel();
    await _accountsSubscription?.cancel();

    _goalsSubscription = _goals.watchAll().listen(
      (goals) =>
          emit(state.copyWith(status: SavingsGoalsStatus.loaded, goals: goals)),
    );
    _savedSubscription = _goals.watchSaved().listen(
      (saved) => emit(state.copyWith(saved: saved)),
    );
    _accountsSubscription = _accounts.watchAll().listen(
      (accounts) => emit(state.copyWith(accounts: accounts)),
    );
  }

  Future<void> create({
    required String name,
    required String targetAmount,
    DateTime? targetDate,
    String? defaultAccountId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: SavingsGoalsStatus.invalid,
          errorMessage: 'Give the goal a name',
        ),
      );
      return;
    }
    final targetMinor = Money.tryParseToMinor(targetAmount);
    if (targetMinor == null || targetMinor <= 0) {
      emit(
        state.copyWith(
          status: SavingsGoalsStatus.invalid,
          errorMessage: 'Enter a target amount like 15000.00',
        ),
      );
      return;
    }
    await _goals.create(
      name: trimmed,
      targetMinor: targetMinor,
      targetDate: targetDate,
      defaultAccountId: defaultAccountId,
    );
    emit(state.copyWith(status: SavingsGoalsStatus.loaded));
  }

  @override
  Future<void> close() async {
    await _goalsSubscription?.cancel();
    await _savedSubscription?.cancel();
    await _accountsSubscription?.cancel();
    return super.close();
  }
}
