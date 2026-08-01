import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<void> addConfirmedSpend({
    required String categoryId,
    required int amountMinor,
    String merchant = 'Test',
  }) async {
    final accountId = (await services.accounts.getDefault()).id;
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: DateTime(2026, 7, 10),
        categoryId: categoryId,
        merchant: merchant,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  Future<CategoryDetailCubit> cubitFor(String categoryId) async {
    final period = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 15),
    );
    return CategoryDetailCubit(
      categories: services.categories,
      budgetPeriods: services.budgetPeriods,
      transactions: services.transactions,
      categoryId: categoryId,
      periodId: period.id,
      periodStartAt: period.startAt,
      periodEndAt: period.endAt,
    );
  }

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  test(
    'spentMinor rolls up direct spend plus every subcategory\'s spend',
    () async {
      final food = (await services.categories.byName('Food'))!;
      final takeaways = await services.categories.create(
        'Takeaways',
        parentId: food.id,
      );

      await addConfirmedSpend(categoryId: food.id, amountMinor: 10000);
      await addConfirmedSpend(categoryId: takeaways.id, amountMinor: 5000);

      final cubit = await cubitFor(food.id);
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.directSpentMinor, 10000);
      expect(cubit.state.spentFor(takeaways.id), 5000);
      expect(cubit.state.spentMinor, 15000);
    },
  );

  test(
    'directTransactions lists only transactions on the category itself',
    () async {
      final food = (await services.categories.byName('Food'))!;
      final takeaways = await services.categories.create(
        'Takeaways',
        parentId: food.id,
      );

      await addConfirmedSpend(
        categoryId: food.id,
        amountMinor: 10000,
        merchant: 'Flowers',
      );
      await addConfirmedSpend(
        categoryId: takeaways.id,
        amountMinor: 5000,
        merchant: 'KFC',
      );

      final cubit = await cubitFor(food.id);
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.directTransactions, hasLength(1));
      expect(cubit.state.directTransactions.single.merchant, 'Flowers');
    },
  );
}
