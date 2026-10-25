import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
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

  test(
    'payday on the 23rd: the next cycle starts then, with its spending',
    () async {
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
      final updatedCurrent = (await services.budgetPeriods.getPeriod(
        current.id,
      ))!;
      final updatedNext = (await services.budgetPeriods.getPeriod(next.id))!;
      expect(day(updatedCurrent.endAt), DateTime(2026, 10, 23));
      expect(day(updatedNext.startAt), DateTime(2026, 10, 23));
      expect(day(updatedNext.endAt), DateTime(2026, 11, 25));
      expect(updatedCurrent.label, '25/09/2026 – 22/10/2026');
      expect(updatedNext.label, startsWith('23/10/2026'));

      expect(await periodOf(before), current.id);
      expect(await periodOf(onPayday), next.id);
      expect(await periodOf(dayAfter), next.id);
    },
  );

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

    await expectLater(
      move(DateTime(2026, 9, 25)),
      throwsA(isA<CycleEditException>()),
    );
    await expectLater(
      move(DateTime(2026, 9)),
      throwsA(isA<CycleEditException>()),
    );
    await expectLater(
      move(DateTime(2026, 11, 25)),
      throwsA(isA<CycleEditException>()),
    );
    await expectLater(
      move(DateTime(2026, 10, 25)),
      throwsA(isA<CycleEditException>()),
    );
  });

  test('refuses cycles that are not neighbours', () async {
    final afterNext = await services.budgetPeriods.shiftPeriod(next, 1);

    await expectLater(
      services.budgetPeriods.moveBoundary(
        earlierId: current.id,
        laterId: afterNext.id,
        newBoundary: DateTime(2026, 11),
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
      (await services.budgetPeriods.categoryBudgetsFor(
        current.id,
      )).single.amountMinor,
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
      earliest: DateTime(2026, 8),
      now: DateTime(2026, 10, 24),
    );

    expect(cycles.first.start, DateTime(2026, 10, 23));
    expect(cycles[1].start, DateTime(2026, 9, 25));
    expect(cycles[1].endExclusive, DateTime(2026, 10, 23));
  });

  test(
    'an adjusted cycle survives a later change to the schedule rule',
    () async {
      await services.budgetPeriods.moveBoundary(
        earlierId: current.id,
        laterId: next.id,
        newBoundary: DateTime(2026, 10, 23),
      );

      // Payday moves to the 28th. Cycles nobody adjusted follow it...
      await services.budgetPeriods.updateSchedule(
        cadence: BudgetCadence.payday,
        anchorDay: 28,
      );
      final later = await services.budgetPeriods.ensurePeriodContaining(
        DateTime(2026, 12, 10),
      );
      expect(day(later.startAt), DateTime(2026, 11, 28));

      // ...while the one that was adjusted keeps its dates.
      expect(
        (await services.budgetPeriods.ensurePeriodContaining(
          DateTime(2026, 10, 24),
        )).id,
        next.id,
      );
      expect(
        day((await services.budgetPeriods.getPeriod(next.id))!.startAt),
        DateTime(2026, 10, 23),
      );
    },
  );

  group('leftover cycles from earlier schedules', () {
    /// A cycle row with exactly these dates, as an earlier schedule rule
    /// could have left behind.
    Future<String> leftover(DateTime start, DateTime endExclusive) async {
      final schedule = await services.budgetPeriods.ensureSchedule();
      final id = Ids.newId();
      final now = Iso.nowUtc();
      await services.db
          .into(services.db.budgetPeriods)
          .insert(
            BudgetPeriodsCompanion.insert(
              id: id,
              userId: services.userId,
              createdAt: now,
              updatedAt: now,
              scheduleId: schedule.id,
              startAt: Iso.fromDateTime(start),
              endAt: Iso.fromDateTime(endExclusive),
              label: 'leftover',
            ),
          );
      return id;
    }

    test(
      'moving onto their exact dates merges them instead of failing',
      () async {
        // Moving the boundary to 1 Nov makes the current cycle
        // 25 Sep to 1 Nov, which a leftover row already is.
        final old = await leftover(DateTime(2026, 9, 25), DateTime(2026, 11));
        final oldTx = await spend(DateTime(2026, 10, 5), current);
        await services.db.customStatement(
          'UPDATE transactions SET period_id = ? WHERE id = ?',
          [old, oldTx],
        );
        final food = (await services.categories.byName('Food'))!;
        final pets = await services.categories.create('Pets');
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: current.id,
          categoryId: food.id,
          amountMinor: 1000,
        );
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: old,
          categoryId: food.id,
          amountMinor: 9999,
        );
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: old,
          categoryId: pets.id,
          amountMinor: 700,
        );

        await services.budgetPeriods.moveBoundary(
          earlierId: current.id,
          laterId: next.id,
          newBoundary: DateTime(2026, 11),
        );

        expect(await services.budgetPeriods.getPeriod(old), isNull);
        expect(await periodOf(oldTx), current.id);
        final budgets = {
          for (final b in await services.budgetPeriods.categoryBudgetsFor(
            current.id,
          ))
            b.categoryId: b.amountMinor,
        };
        // The cycle's own envelope wins; the one it lacked is carried over.
        expect(budgets[food.id], 1000);
        expect(budgets[pets.id], 700);
        expect(
          day((await services.budgetPeriods.getPeriod(current.id))!.endAt),
          DateTime(2026, 11),
        );
      },
    );

    test(
      'the cycle list stays unbroken after several rule changes and an edit',
      () async {
        final repo = services.budgetPeriods;
        for (final m in [8, 9, 10, 11, 12]) {
          await repo.ensurePeriodContaining(DateTime(2026, m, 10));
        }
        for (final payday in [6, 24]) {
          await repo.updateSchedule(
            cadence: BudgetCadence.payday,
            anchorDay: payday,
          );
          for (final m in [8, 9, 10, 11, 12]) {
            await repo.ensurePeriodContaining(DateTime(2026, m, 28));
          }
        }
        final now = await repo.ensurePeriodContaining(DateTime(2026, 10, 25));
        final after = await repo.shiftPeriod(now, 1);
        await repo.moveBoundary(
          earlierId: now.id,
          laterId: after.id,
          newBoundary: DateTime(2026, 11, 22),
        );

        final list = await repo.cyclesBetween(
          earliest: DateTime(2026, 8),
          now: DateTime(2026, 11, 25),
        );

        expect(list.first.start, DateTime(2026, 11, 22));
        for (var i = 0; i + 1 < list.length; i++) {
          expect(list[i + 1].endExclusive, list[i].start);
        }
      },
    );
  });
}
