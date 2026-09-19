import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/savings_goal_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';
import 'package:intellispendiq/domain/models/savings_goal_entry.dart';

part 'savings_goal_detail_state.dart';

/// One goal's live saved total, its contribution/withdrawal history, and
/// the actions that move money into, out of, or through it.
class SavingsGoalDetailCubit extends Cubit<SavingsGoalDetailState> {
  SavingsGoalDetailCubit({
    required SavingsGoalRepository goals,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required String goalId,
  }) : _goals = goals,
       _accounts = accounts,
       _categories = categories,
       super(SavingsGoalDetailState(goalId: goalId));

  final SavingsGoalRepository _goals;
  final AccountRepository _accounts;
  final CategoryRepository _categories;

  StreamSubscription<List<SavingsGoal>>? _goalsSubscription;
  StreamSubscription<Map<String, int>>? _savedSubscription;
  StreamSubscription<List<SavingsGoalEntry>>? _entriesSubscription;
  StreamSubscription<List<Account>>? _accountsSubscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: SavingsGoalDetailStatus.loading));
    await _goalsSubscription?.cancel();
    await _savedSubscription?.cancel();
    await _entriesSubscription?.cancel();
    await _accountsSubscription?.cancel();

    emit(state.copyWith(categories: await _categories.getAll()));

    _goalsSubscription = _goals.watchAll().listen(_onGoals);
    _savedSubscription = _goals.watchSaved().listen(
      (saved) => emit(state.copyWith(savedMinor: saved[state.goalId] ?? 0)),
    );
    _entriesSubscription = _goals.watchEntries(state.goalId).listen(
      (entries) => emit(state.copyWith(entries: entries)),
    );
    _accountsSubscription = _accounts.watchAll().listen(
      (accounts) => emit(state.copyWith(accounts: accounts)),
    );
  }

  void _onGoals(List<SavingsGoal> goals) {
    final goal = goals.where((g) => g.id == state.goalId).firstOrNull;
    if (goal == null) {
      emit(state.copyWith(status: SavingsGoalDetailStatus.notFound));
      return;
    }
    emit(state.copyWith(status: SavingsGoalDetailStatus.loaded, goal: goal));
  }

  Future<void> contribute({
    required String accountId,
    required String amount,
    required DateTime transactedAt,
    String? note,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: SavingsGoalDetailStatus.invalid,
          errorMessage: 'Enter an amount like 250.00',
        ),
      );
      return;
    }
    await _goals.contribute(
      goalId: state.goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      note: note,
    );
    emit(state.copyWith(status: SavingsGoalDetailStatus.loaded));
  }

  Future<void> withdraw({
    required String accountId,
    required String amount,
    required DateTime transactedAt,
    String? note,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: SavingsGoalDetailStatus.invalid,
          errorMessage: 'Enter an amount like 250.00',
        ),
      );
      return;
    }
    if (amountMinor > state.savedMinor) {
      emit(
        state.copyWith(
          status: SavingsGoalDetailStatus.invalid,
          errorMessage: 'You can only withdraw what is saved toward this goal',
        ),
      );
      return;
    }
    await _goals.withdraw(
      goalId: state.goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      note: note,
    );
    emit(state.copyWith(status: SavingsGoalDetailStatus.loaded));
  }

  Future<void> spend({
    required String accountId,
    required String amount,
    required DateTime transactedAt,
    String? categoryId,
    String? merchant,
    String? description,
  }) async {
    final amountMinor = Money.tryParseToMinor(amount);
    if (amountMinor == null || amountMinor <= 0) {
      emit(
        state.copyWith(
          status: SavingsGoalDetailStatus.invalid,
          errorMessage: 'Enter an amount like 250.00',
        ),
      );
      return;
    }
    await _goals.spend(
      goalId: state.goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      categoryId: categoryId,
      merchant: merchant,
      description: description,
    );
    emit(state.copyWith(status: SavingsGoalDetailStatus.loaded));
  }

  Future<void> deleteGoal() => _goals.delete(state.goalId);

  @override
  Future<void> close() async {
    await _goalsSubscription?.cancel();
    await _savedSubscription?.cancel();
    await _entriesSubscription?.cancel();
    await _accountsSubscription?.cancel();
    return super.close();
  }
}
