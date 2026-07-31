import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/domain/models/budget_schedule.dart';
import 'package:intellispendiq/domain/models/enums.dart';

part 'budget_cycle_state.dart';

/// Edits the user's repeating budget schedule (cadence + anchors).
class BudgetCycleCubit extends Cubit<BudgetCycleState> {
  BudgetCycleCubit(this._budgetPeriods) : super(const BudgetCycleState());

  final BudgetPeriodRepository _budgetPeriods;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: BudgetCycleStatus.loading));
    final schedule = await _budgetPeriods.ensureSchedule();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetCycleStatus.loaded,
        schedule: schedule,
      ),
    );
  }

  Future<void> selectCadence(BudgetCadence cadence) async {
    final current = state.schedule;
    if (current == null || current.cadence == cadence) return;

    emit(state.copyWith(status: BudgetCycleStatus.saving));
    final updated = await _budgetPeriods.updateSchedule(
      cadence: cadence,
      anchorDay: cadence == BudgetCadence.payday
          ? (current.anchorDay ?? 25)
          : null,
      clearAnchorDay: cadence != BudgetCadence.payday,
      anchorDate:
          cadence == BudgetCadence.biweekly ||
              cadence == BudgetCadence.everyFourWeeks
          ? (current.anchorDate ?? Iso.localDateKey(DateTime.now()))
          : null,
      clearAnchorDate:
          cadence != BudgetCadence.biweekly &&
          cadence != BudgetCadence.everyFourWeeks,
      startWeekday: cadence == BudgetCadence.weekly
          ? (current.startWeekday ?? DateTime.monday)
          : null,
      clearStartWeekday: cadence != BudgetCadence.weekly,
    );
    await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetCycleStatus.loaded,
        schedule: updated,
        savedMessage: 'Budget cycle updated',
      ),
    );
  }

  Future<void> setAnchorDay(int day) async {
    final schedule = state.schedule;
    if (schedule == null || schedule.cadence != BudgetCadence.payday) return;
    emit(state.copyWith(status: BudgetCycleStatus.saving));
    final updated = await _budgetPeriods.updateSchedule(
      cadence: BudgetCadence.payday,
      anchorDay: day.clamp(1, 31),
    );
    await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetCycleStatus.loaded,
        schedule: updated,
        savedMessage: 'Payday day updated',
      ),
    );
  }

  Future<void> setStartWeekday(int weekday) async {
    final schedule = state.schedule;
    if (schedule == null || schedule.cadence != BudgetCadence.weekly) return;
    emit(state.copyWith(status: BudgetCycleStatus.saving));
    final updated = await _budgetPeriods.updateSchedule(
      cadence: BudgetCadence.weekly,
      startWeekday: weekday,
    );
    await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetCycleStatus.loaded,
        schedule: updated,
        savedMessage: 'Week start updated',
      ),
    );
  }

  Future<void> setAnchorDate(DateTime localDate) async {
    final schedule = state.schedule;
    if (schedule == null) return;
    if (schedule.cadence != BudgetCadence.biweekly &&
        schedule.cadence != BudgetCadence.everyFourWeeks) {
      return;
    }
    emit(state.copyWith(status: BudgetCycleStatus.saving));
    final updated = await _budgetPeriods.updateSchedule(
      cadence: schedule.cadence,
      anchorDate: Iso.localDateKey(localDate),
    );
    await _budgetPeriods.ensurePeriodContaining(DateTime.now());
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BudgetCycleStatus.loaded,
        schedule: updated,
        savedMessage: 'Anchor date updated',
      ),
    );
  }
}
