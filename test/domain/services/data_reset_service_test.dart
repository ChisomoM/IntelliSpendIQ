import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices source;

  Future<void> addSpend({String merchant = 'Shoprite'}) async {
    final foodCategoryId = (await source.categories.byName('Food'))!.id;
    final accountId = (await source.accounts.getDefault()).id;
    await source.transactions.insertDraft(
      TransactionDraft(
        amountMinor: 5000,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: DateTime(2026, 7, 10),
        categoryId: foodCategoryId,
        merchant: merchant,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  setUp(() async {
    source = await createTestServices();
  });
  tearDown(() async => source.dispose());

  group('resetAllData', () {
    test('clears transactions, accounts, and categories', () async {
      await addSpend();
      final extraCategory = await source.categories.create('Pets');
      final extraAccount = await source.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );

      await source.dataResetService.resetAllData();

      expect(await source.transactions.getAllForExport(), isEmpty);
      final categories = await source.categories.getAll();
      expect(categories.map((c) => c.id), isNot(contains(extraCategory.id)));
      final accounts = await source.accounts.getAll();
      expect(accounts.map((a) => a.id), isNot(contains(extraAccount.id)));
    });

    test('re-seeds day-one defaults', () async {
      await addSpend();

      await source.dataResetService.resetAllData();

      final categories = await source.categories.getAll();
      expect(categories.map((c) => c.name), contains('Food'));
      final accounts = await source.accounts.getAll();
      expect(accounts, hasLength(1));
      expect(accounts.single.isDefault, isTrue);
      final schedule = await source.budgetPeriods.getSchedule();
      expect(schedule, isNotNull);
    });

    test('pins the SMS backfill watermark to now', () async {
      await source.settings.set(
        SettingsRepository.smsBackfillWatermarkKey,
        '1000',
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      await source.dataResetService.resetAllData();
      final after = DateTime.now().millisecondsSinceEpoch;

      final watermark = await source.settings.getInt(
        SettingsRepository.smsBackfillWatermarkKey,
      );
      expect(watermark, isNotNull);
      expect(watermark!, inInclusiveRange(before, after));
    });
  });
}
