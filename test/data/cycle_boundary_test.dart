import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late BudgetPeriod current;
  late BudgetPeriod next;

  /// Records a debit on [on], tied to [period] the way the entry form
  /// does it, and returns its id.
  Future<String> spend(DateTime on, BudgetPeriod period) async {
    final accountId = (await services.accounts.getDefault()).id;
    final tx = await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: 1000,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: on,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
      periodId: period.id,
    );
    return tx.id;
  }

  Future<String?> periodOf(String transactionId) async =>
      (await services.transactions.byId(transactionId))!.periodId;

  DateTime day(String iso) => DateTime.parse(iso).toLocal();

  setUp(() async {
    services = await createTestServices();
    // Payday on the 25th: cycles run 25th to 25th.
    await services.budgetPeriods.updateSchedule(
      cadence: BudgetCadence.payday,
      anchorDay: 25,
    );
    current = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 10, 10),
    );
    next = await services.budgetPeriods.shiftPeriod(current, 1);
  });
  tearDown(() async => services.dispose());

  test('starts as a payday cycle, 25 Sep to 25 Oct', () {
    expect(day(current.startAt), DateTime(2026, 9, 25));
    expect(day(current.endAt), DateTime(2026, 10, 25));
    expect(day(next.startAt), DateTime(2026, 10, 25));
  });

  test('payday on the 23rd: the next cycle starts then, with its spending', () async {
    final before = await spend(DateTime(2026, 10, 22, 12), current);
    final onPayday = await spend(DateTime(2026, 10, 23, 9), current);
    final dayAfter = await spend(DateTime(2026, 10, 24, 18), current);

    final preview = await services.budgetPeriods.moveBoundary(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: DateTime(2026, 10, 23),
    );

    expect(preview.transactionsMoving, 2);
    expect(preview.movesIntoLater, isTrue);
    final updatedCurrent = (await services.budgetPeriods.getPeriod(current.id))!;
    final updatedNext = (await services.budgetPeriods.getPeriod(next.id))!;
    expect(day(updatedCurrent.endAt), DateTime(2026, 10, 23));
    expect(day(updatedNext.startAt), DateTime(2026, 10, 23));
    expect(day(updatedNext.endAt), DateTime(2026, 11, 25));
    expect(updatedCurrent.label, '25/09/2026 – 22/10/2026');
    expect(updatedNext.label, startsWith('23/10/2026'));

    expect(await periodOf(before), current.id);
    expect(await periodOf(onPayday), next.id);
    expect(await periodOf(dayAfter), next.id);
  });

  test('a saved cycle keeps its dates when looked up by date', () async {
    await services.budgetPeriods.moveBoundary(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: DateTime(2026, 10, 23),
    );

    expect(
      (await services.budgetPeriods.ensurePeriodContaining(
        DateTime(2026, 10, 22),
      )).id,
      current.id,
    );
    expect(
      (await services.budgetPeriods.ensurePeriodContaining(
        DateTime(2026, 10, 24),
      )).id,
      next.id,
    );
    // Stepping across the moved boundary lands on the same cycles.
    expect(
      (await services.budgetPeriods.shiftPeriod(
        (await services.budgetPeriods.getPeriod(next.id))!,
        -1,
      )).id,
      current.id,
    );
    // Cycles after it still follow the rule.
    final after = await services.budgetPeriods.shiftPeriod(
      (await services.budgetPeriods.getPeriod(next.id))!,
      1,
    );
    expect(day(after.startAt), DateTime(2026, 11, 25));
  });

  test('payday late on the 27th: the boundary moves later', () async {
    final onTheDay = await spend(DateTime(2026, 10, 25, 10), next);
    final dayAfter = await spend(DateTime(2026, 10, 26, 10), next);
    final payday = await spend(DateTime(2026, 10, 27, 8), next);

    final preview = await services.budgetPeriods.moveBoundary(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: DateTime(2026, 10, 27),
    );

    expect(preview.transactionsMoving, 2);
    expect(preview.movesIntoLater, isFalse);
    expect(await periodOf(onTheDay), current.id);
    expect(await periodOf(dayAfter), current.id);
    expect(await periodOf(payday), next.id);
  });

  test('previewing changes nothing', () async {
    final tx = await spend(DateTime(2026, 10, 24), current);

    final preview = await services.budgetPeriods.previewBoundaryMove(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: DateTime(2026, 10, 23),
    );

    expect(preview.transactionsMoving, 1);
    expect(await periodOf(tx), current.id);
    expect(
      day((await services.budgetPeriods.getPeriod(current.id))!.endAt),
      DateTime(2026, 10, 25),
    );
  });

  test('refuses dates that would empty a cycle or do nothing', () async {
    Future<void> move(DateTime on) => services.budgetPeriods.moveBoundary(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: on,
    );

    await expectLater(move(DateTime(2026, 9, 25)), throwsA(isA<CycleEditException>()));
    await expectLater(move(DateTime(2026, 9, 1)), throwsA(isA<CycleEditException>()));
    await expectLater(move(DateTime(2026, 11, 25)), throwsA(isA<CycleEditException>()));
    await expectLater(move(DateTime(2026, 10, 25)), throwsA(isA<CycleEditException>()));
  });

  test('refuses cycles that are not neighbours', () async {
    final afterNext = await services.budgetPeriods.shiftPeriod(next, 1);

    await expectLater(
      services.budgetPeriods.moveBoundary(
        earlierId: current.id,
        laterId: afterNext.id,
        newBoundary: DateTime(2026, 11, 1),
      ),
      throwsA(isA<CycleEditException>()),
    );
  });

  test('budgets already set stay with their own cycle', () async {
    final food = (await services.categories.byName('Food'))!;
    await services.budgetPeriods.upsertCategoryBudget(
      periodId: current.id,
      categoryId: food.id,
      amountMinor: 50000,
    );

    await services.budgetPeriods.moveBoundary(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: DateTime(2026, 10, 23),
    );

    expect(
      (await services.budgetPeriods.categoryBudgetsFor(current.id)).single.amountMinor,
      50000,
    );
    expect(await services.budgetPeriods.categoryBudgetsFor(next.id), isEmpty);
  });

  test('the cycle list used by exports reflects adjusted dates', () async {
    await services.budgetPeriods.moveBoundary(
      earlierId: current.id,
      laterId: next.id,
      newBoundary: DateTime(2026, 10, 23),
    );

    final cycles = await services.budgetPeriods.cyclesBetween(
      earliest: DateTime(2026, 8, 1),
      now: DateTime(2026, 10, 24),
    );

    expect(cycles.first.start, DateTime(2026, 10, 23));
    expect(cycles[1].start, DateTime(2026, 9, 25));
    expect(cycles[1].endExclusive, DateTime(2026, 10, 23));
  });
}
