import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/services/budget_import_service.dart';

import '../../support/test_harness.dart';

BudgetImportService _service(AppServices s) => BudgetImportService(
  db: s.db,
  transactions: s.transactions,
  categories: s.categories,
  accounts: s.accounts,
  budgetPeriods: s.budgetPeriods,
  tempDirectory: () async => Directory.systemTemp,
);

void main() {
  late AppServices services;
  late BudgetImportService importer;

  setUp(() async {
    services = await createTestServices();
    importer = _service(services);
  });
  tearDown(() async => services.dispose());

  const header = 'Date,Category,Sub category,Amount,Paid,Account,Note\n';

  test('requires the Date, Category and Amount columns', () {
    expect(
      importer.parse('Date,Amount\n2026-10-05,10'),
      throwsA(isA<FormatException>()),
    );
  });

  test('saves paid lines as confirmed and unpaid as planned', () async {
    final plan = await importer.parse(
      '${header}2026-10-05,Food,,400.00,yes,,Lunch\n'
      '2026-10-28,Food,,6500,no,,\n',
    );
    expect(plan.errors, isEmpty);
    expect(plan.paidCount, 1);
    expect(plan.plannedCount, 1);

    expect(await importer.apply(plan), 2);

    final all = await services.transactions.getAllForExport();
    final lunch = all.firstWhere((tx) => tx.amountMinor == 40000);
    final rent = all.firstWhere((tx) => tx.amountMinor == 650000);
    expect(lunch.status, TxStatus.confirmed);
    expect(lunch.description, 'Lunch');
    expect(lunch.direction, TxDirection.debit);
    expect(rent.status, TxStatus.planned);
  });

  test('creates a missing category and sub category with its parent', () async {
    final plan = await importer.parse(
      '${header}2026-10-05,Pets,Vet,250,no,,\n',
    );
    expect(plan.newCategories, ['Pets', 'Pets > Vet']);

    await importer.apply(plan);

    final pets = (await services.categories.byName('Pets'))!;
    final vet = (await services.categories.getAll()).firstWhere(
      (c) => c.name == 'Vet',
    );
    expect(pets.parentId, isNull);
    expect(vet.parentId, pets.id);
    final tx = (await services.transactions.getAllForExport()).single;
    expect(tx.categoryId, vet.id);
  });

  test('reuses an existing category, ignoring case and spacing', () async {
    final food = (await services.categories.byName('Food'))!;
    final plan = await importer.parse('${header}2026-10-05,  food ,,10,no,,\n');

    expect(plan.newCategories, isEmpty);
    await importer.apply(plan);
    final tx = (await services.transactions.getAllForExport()).single;
    expect(tx.categoryId, food.id);
  });

  test('charges the named account, else the default', () async {
    final bank = await services.accounts.create(
      name: 'Bank',
      type: AccountType.bank,
    );
    final plan = await importer.parse(
      '${header}2026-10-05,Food,,10,no,Bank,\n'
      '2026-10-06,Food,,20,no,,\n',
    );
    await importer.apply(plan);

    final all = await services.transactions.getAllForExport();
    final defaultId = (await services.accounts.getDefault()).id;
    expect(all.firstWhere((tx) => tx.amountMinor == 1000).accountId, bank.id);
    expect(
      all.firstWhere((tx) => tx.amountMinor == 2000).accountId,
      defaultId,
    );
  });

  test('puts each line in the cycle holding its date', () async {
    await importer.apply(
      await importer.parse('${header}2026-03-15,Food,,10,no,,\n'),
    );
    final tx = (await services.transactions.getAllForExport()).single;
    final period = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 3, 15),
    );
    expect(tx.periodId, period.id);
  });

  test('reports bad lines and leaves them out', () async {
    final plan = await importer.parse(
      '${header}not a date,Food,,10,no,,\n'
      '2026-10-05,Food,,-5,no,,\n'
      '2026-10-05,Food,,10,maybe,,\n'
      '2026-10-05,Food,,10,no,Nowhere,\n'
      '2026-02-31,Food,,10,no,,\n'
      '2026-10-05,Income,,10,no,,\n'
      '2026-10-05,Food,,10,no,,\n',
    );
    expect(plan.errors.map((e) => e.line), [2, 3, 4, 5, 6, 7]);
    expect(plan.rows.single.line, 8);
  });

  test('accepts DD/MM/YYYY dates', () async {
    final plan = await importer.parse('${header}05/10/2026,Food,,10,no,,\n');
    expect(plan.errors, isEmpty);
    expect(plan.rows.single.date, DateTime(2026, 10, 5, 12));
  });

  test('importing the same file twice adds nothing the second time', () async {
    const file =
        '${header}2026-10-05,Food,,10,no,,\n'
        '2026-10-05,Food,,10,no,,\n';
    await importer.apply(await importer.parse(file));

    final again = await importer.parse(file);
    expect(again.rows, isEmpty);
    expect(again.alreadyPresent, 2);
    expect(await services.transactions.getAllForExport(), hasLength(2));
  });

  test('a longer file only adds the new lines', () async {
    await importer.apply(
      await importer.parse('${header}2026-10-05,Food,,10,no,,\n'),
    );
    final plan = await importer.parse(
      '${header}2026-10-05,Food,,10,no,,\n'
      '2026-10-06,Food,,20,no,,\n',
    );
    expect(plan.alreadyPresent, 1);
    expect(plan.rows.single.amountMinor, 2000);
  });
}
