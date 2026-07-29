import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<TransactionsCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    return TransactionsCubit(services.transactions);
  }

  group('TransactionsCubit', () {
    test('subscribe() streams the recent transaction list', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final accountId = (await services.accounts.getDefault()).id;
      await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 5000,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: DateTime.now(),
          merchant: 'Shoprite',
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );

      cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'Shoprite');
    });

    test('delete() removes a transaction from the list', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final accountId = (await services.accounts.getDefault()).id;
      final saved = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 5000,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: DateTime.now(),
          merchant: 'Duplicate transfer',
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      cubit.subscribe();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.transactions, hasLength(1));

      await cubit.delete(saved.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, isEmpty);
    });
  });
}
