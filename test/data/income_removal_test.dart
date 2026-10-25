import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late BudgetPeriod july;
  late BudgetPeriod august;
  late Category salary;
  late String accountId;

  Future<void> plan(BudgetPeriod period, int amountMinor) =>
      services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: salary.id,
        amountMinor: amountMinor,
      );

  Future<void> markPaid(BudgetPeriod period, int amountMinor) =>
      services.budgetPeriods.markCategoryBudgetPaid(
        periodId: period.id,
        categoryId: salary.id,
        accountId: accountId,
        amountMinor: amountMinor,
        transactedAt: DateTime(2026, 7, 25),
      );

  Future<Map<String, int>> amountsIn(BudgetPeriod period) async => {
    for (final b in await services.budgetPeriods.categoryBudgetsFor(period.id))
      b.categoryId: b.amountMinor,
  };

  setUp(() async {
    services = await createTestServices();
    july = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 10),
    );
    august = await services.budgetPeriods.shiftPeriod(july, 1);
    salary = await services.categories.create(
      'Salary',
      type: CategoryType.income,
    );
    accountId = (await services.accounts.getDefault()).id;
  });
  tearDown(() async => services.dispose());

  test('removes a planned income from one cycle and leaves the rest', () async {
    await plan(july, 800000);
    await plan(august, 800000);

    final removed = await services.budgetPeriods.removeIncomeFromPeriod(
      periodId: july.id,
      categoryId: salary.id,
    );

    expect(removed, isTrue);
    expect(await amountsIn(july), isEmpty);
    expect(await amountsIn(august), {salary.id: 800000});
    // The income source itself is untouched.
    expect(await services.categories.byName('Salary'), isNotNull);
    final totals = await services.budgetPeriods.incomeTotalsForPeriod(july.id);
    expect(totals.provisionalMinor, 0);
  });

  test(
    'a paid income keeps its money received unless asked to delete it',
    () async {
      await plan(july, 800000);
      await markPaid(july, 750000);
      expect(await services.transactions.getAllForExport(), hasLength(1));

      await services.budgetPeriods.removeIncomeFromPeriod(
        periodId: july.id,
        categoryId: salary.id,
      );

      expect(await amountsIn(july), isEmpty);
      final kept = await services.transactions.getAllForExport();
      expect(kept.single.amountMinor, 750000);
      expect(kept.single.direction, TxDirection.credit);
      // The money did arrive, so the cycle still counts it as income.
      final totals = await services.budgetPeriods.incomeTotalsForPeriod(
        july.id,
      );
      expect(totals.actualMinor, 750000);
    },
  );

  test('can delete the money received along with it', () async {
    await plan(july, 800000);
    await markPaid(july, 750000);

    await services.budgetPeriods.removeIncomeFromPeriod(
      periodId: july.id,
      categoryId: salary.id,
      deleteReceivedTransaction: true,
    );

    expect(await amountsIn(july), isEmpty);
    expect(await services.transactions.getAllForExport(), isEmpty);
    final totals = await services.budgetPeriods.incomeTotalsForPeriod(july.id);
    expect(totals.actualMinor, 0);
  });

  test('deleting the received money only touches that cycle', () async {
    await plan(july, 800000);
    await markPaid(july, 750000);
    await plan(august, 800000);
    await services.budgetPeriods.markCategoryBudgetPaid(
      periodId: august.id,
      categoryId: salary.id,
      accountId: accountId,
      amountMinor: 800000,
      transactedAt: DateTime(2026, 8, 25),
    );

    await services.budgetPeriods.removeIncomeFromPeriod(
      periodId: july.id,
      categoryId: salary.id,
      deleteReceivedTransaction: true,
    );

    final left = await services.transactions.getAllForExport();
    expect(left.single.amountMinor, 800000);
    expect(await amountsIn(august), {salary.id: 800000});
  });

  test('marking it paid again after removing records a new receipt', () async {
    await plan(july, 800000);
    await markPaid(july, 750000);
    await services.budgetPeriods.removeIncomeFromPeriod(
      periodId: july.id,
      categoryId: salary.id,
    );

    // The kept transaction is no longer tied to the cycle, so it is not
    // silently reused.
    await plan(july, 800000);
    final totals = await services.budgetPeriods.incomeTotalsForPeriod(july.id);
    expect(totals.actualMinor, 750000);
    expect(totals.provisionalMinor, 800000);
    await markPaid(july, 800000);
    expect(await services.transactions.getAllForExport(), hasLength(2));
  });

  test('does nothing when there is no line to remove', () async {
    expect(
      await services.budgetPeriods.removeIncomeFromPeriod(
        periodId: july.id,
        categoryId: salary.id,
      ),
      isFalse,
    );
  });

  test('refuses an expense category', () async {
    final food = (await services.categories.byName('Food'))!;
    await services.budgetPeriods.upsertCategoryBudget(
      periodId: july.id,
      categoryId: food.id,
      amountMinor: 50000,
    );

    final removed = await services.budgetPeriods.removeIncomeFromPeriod(
      periodId: july.id,
      categoryId: food.id,
    );

    expect(removed, isFalse);
    expect(await amountsIn(july), {food.id: 50000});
  });
}
