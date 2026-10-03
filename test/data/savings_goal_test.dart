import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late String bankId;
  late String cashId;

  setUp(() async {
    services = await createTestServices();
    bankId = (await services.accounts.create(
      name: 'Bank',
      type: AccountType.bank,
    )).id;
    cashId = (await services.accounts.create(
      name: 'Cash',
      type: AccountType.cash,
    )).id;
  });
  tearDown(() async => services.dispose());

  Future<void> addIncome({
    required String accountId,
    required int amountMinor,
    required DateTime at,
  }) async {
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.credit,
        source: TxSource.manual,
        transactedAt: at,
        merchant: 'Salary',
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  group('SavingsGoalRepository.contribute', () {
    test('really transfers money into the goal\'s own account', () async {
      final goal = await services.savingsGoals.create(
        name: 'New Laptop',
        targetMinor: 1500000,
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 200000,
        transactedAt: DateTime(2026, 7, 1),
      );

      final saved = await services.savingsGoals.watchSaved().first;
      expect(saved[goal.id], 200000);

      final txs = await services.transactions.getAllForExport();
      expect(
        txs,
        isEmpty,
        reason: 'a contribution is a transfer, never a transaction',
      );

      final goalAccountId = (await services.savingsGoals.watchAll().first)
          .single
          .accountId!;
      final balances = await services.accounts.watchComputedBalances().first;
      expect(
        balances[bankId],
        -200000,
        reason: 'the contribution really leaves the source account',
      );
      expect(
        balances[goalAccountId],
        200000,
        reason: 'and really arrives in the goal\'s own hidden account',
      );
    });

    test('two contributions from different accounts sum correctly', () async {
      final goal = await services.savingsGoals.create(
        name: 'Trip',
        targetMinor: 500000,
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 100000,
        transactedAt: DateTime(2026, 7, 1),
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: cashId,
        amountMinor: 50000,
        transactedAt: DateTime(2026, 7, 2),
      );

      final saved = await services.savingsGoals.watchSaved().first;
      expect(saved[goal.id], 150000);
    });
  });

  group('SavingsGoalRepository.withdraw', () {
    test('really transfers money back without touching spend totals', () async {
      final goal = await services.savingsGoals.create(
        name: 'New Phone',
        targetMinor: 300000,
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 100000,
        transactedAt: DateTime(2026, 7, 1),
      );
      await services.savingsGoals.withdraw(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 40000,
        transactedAt: DateTime(2026, 7, 5),
      );

      final saved = await services.savingsGoals.watchSaved().first;
      expect(saved[goal.id], 60000);
      expect(await services.transactions.getAllForExport(), isEmpty);

      final balances = await services.accounts.watchComputedBalances().first;
      expect(
        balances[bankId],
        -60000,
        reason: 'contributed 1000 then took 400 back, net 600 still away',
      );
    });

    test('refuses to withdraw more than is saved', () async {
      final goal = await services.savingsGoals.create(
        name: 'New Phone',
        targetMinor: 300000,
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 50000,
        transactedAt: DateTime(2026, 7, 1),
      );

      expect(
        () => services.savingsGoals.withdraw(
          goalId: goal.id,
          accountId: bankId,
          amountMinor: 60000,
          transactedAt: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
    });
  });

  group('SavingsGoalRepository.spend', () {
    test(
      'income 10000, contribute 2000, spend 1800 reports 1800 expense, '
      'not 3800',
      () async {
        // Earn 10,000.
        await addIncome(
          accountId: bankId,
          amountMinor: 1000000,
          at: DateTime(2026, 7, 1),
        );

        final goal = await services.savingsGoals.create(
          name: 'New Phone',
          targetMinor: 300000,
        );
        await services.savingsGoals.contribute(
          goalId: goal.id,
          accountId: bankId,
          amountMinor: 200000,
          transactedAt: DateTime(2026, 7, 2),
        );

        await services.savingsGoals.spend(
          goalId: goal.id,
          accountId: bankId,
          amountMinor: 180000,
          transactedAt: DateTime(2026, 7, 10),
          merchant: 'Phone Shop',
        );

        final totalSpent = await services.transactions.totalSpentInRange(
          from: Iso.fromDateTime(DateTime(2026, 7, 1)),
          to: Iso.fromDateTime(DateTime(2026, 8, 1)),
        );
        expect(totalSpent, 180000);

        final saved = await services.savingsGoals.watchSaved().first;
        expect(
          saved[goal.id],
          20000,
          reason: 'only the spent 1800 of the saved 2000 was released',
        );

        final balances = await services.accounts.watchComputedBalances().first;
        expect(
          balances[bankId],
          1000000 - 200000,
          reason:
              'the 2000 already left the bank when it was contributed; '
              'a fully goal-funded purchase draws from the goal\'s own '
              'account, not the bank again',
        );
      },
    );

    test('spending more than saved charges the shortfall as ordinary spend', () async {
      final goal = await services.savingsGoals.create(
        name: 'New Phone',
        targetMinor: 300000,
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 100000,
        transactedAt: DateTime(2026, 7, 1),
      );

      final tx = await services.savingsGoals.spend(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 150000,
        transactedAt: DateTime(2026, 7, 10),
        merchant: 'Phone Shop',
      );

      expect(
        tx.amountMinor,
        50000,
        reason:
            'the returned transaction is the shortfall leg charged to '
            'the real account; the other 1000 was already drawn from '
            'the goal\'s own account',
      );
      final totalSpent = await services.transactions.totalSpentInRange(
        from: Iso.fromDateTime(DateTime(2026, 7, 1)),
        to: Iso.fromDateTime(DateTime(2026, 8, 1)),
      );
      expect(
        totalSpent,
        150000,
        reason: 'the two legs together still add up to the full price paid',
      );

      final saved = await services.savingsGoals.watchSaved().first;
      expect(saved[goal.id], 0);

      final balances = await services.accounts.watchComputedBalances().first;
      expect(balances[bankId], -150000);
    });

    test('spending less than saved leaves the surplus saved', () async {
      final goal = await services.savingsGoals.create(
        name: 'New Phone',
        targetMinor: 300000,
      );
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 200000,
        transactedAt: DateTime(2026, 7, 1),
      );

      await services.savingsGoals.spend(
        goalId: goal.id,
        accountId: bankId,
        amountMinor: 150000,
        transactedAt: DateTime(2026, 7, 10),
        merchant: 'Phone Shop',
      );

      final saved = await services.savingsGoals.watchSaved().first;
      expect(saved[goal.id], 50000);
    });
  });

  group('SavingsGoalRepository.delete', () {
    test(
      'transfers saved money back to each source account, then hides the goal',
      () async {
        final goal = await services.savingsGoals.create(
          name: 'Trip',
          targetMinor: 500000,
        );
        await services.savingsGoals.contribute(
          goalId: goal.id,
          accountId: bankId,
          amountMinor: 100000,
          transactedAt: DateTime(2026, 7, 1),
        );
        await services.savingsGoals.contribute(
          goalId: goal.id,
          accountId: cashId,
          amountMinor: 50000,
          transactedAt: DateTime(2026, 7, 2),
        );

        await services.savingsGoals.delete(goal.id);

        final saved = await services.savingsGoals.watchSaved().first;
        expect(saved[goal.id] ?? 0, 0);

        final goals = await services.savingsGoals.watchAll().first;
        expect(goals, isEmpty);

        final balances = await services.accounts.watchComputedBalances().first;
        expect(
          balances[bankId],
          0,
          reason: 'deleting the goal returns the 1000 it took from Bank',
        );
        expect(
          balances[cashId],
          0,
          reason: 'and the 500 it took from Cash',
        );
      },
    );
  });
}
