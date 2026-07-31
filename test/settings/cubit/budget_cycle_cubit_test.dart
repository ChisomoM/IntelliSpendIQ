import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/settings/cubit/cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<BudgetCycleCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    return BudgetCycleCubit(services.budgetPeriods);
  }

  group('BudgetCycleCubit', () {
    test('loads the default calendar-month schedule', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, BudgetCycleStatus.loaded);
      expect(cubit.state.schedule?.cadence, BudgetCadence.calendarMonth);
    });

    test('selectCadence switches to payday with day 25', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.selectCadence(BudgetCadence.payday);

      expect(cubit.state.schedule?.cadence, BudgetCadence.payday);
      expect(cubit.state.schedule?.anchorDay, 25);
      expect(cubit.state.savedMessage, isNotNull);

      final period = await services.budgetPeriods.ensurePeriodContaining(
        DateTime(2026, 7, 28),
      );
      expect(period.label, contains('25/'));
    });

    test('setAnchorDay updates payday', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.selectCadence(BudgetCadence.payday);

      await cubit.setAnchorDay(15);

      expect(cubit.state.schedule?.anchorDay, 15);
    });

    test('weekly cadence stores start weekday', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.selectCadence(BudgetCadence.weekly);
      await cubit.setStartWeekday(DateTime.friday);

      expect(cubit.state.schedule?.cadence, BudgetCadence.weekly);
      expect(cubit.state.schedule?.startWeekday, DateTime.friday);
    });
  });
}
