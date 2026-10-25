import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/shopping_trip_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late ShoppingTripRepository trips;
  late String accountId;
  late Category groceries;
  late Category clothes;

  setUp(() async {
    services = await createTestServices();
    trips = services.shoppingTrips;
    accountId = (await services.accounts.getDefault()).id;
    groceries = await services.categories.create('Groceries');
    clothes = await services.categories.create('Clothes');
  });
  tearDown(() async => services.dispose());

  Future<Transaction> planned(
    String name,
    int amountMinor,
    Category category, {
    String? description,
  }) {
    return services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: DateTime.now(),
        merchant: name,
        description: description,
        categoryId: category.id,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.planned,
    );
  }

  Future<int> transactionCount() async =>
      (await services.transactions.watchRecent(limit: 1000).first).length;

  group('startTrip', () {
    test(
      'copies planned transactions into the trip without touching them',
      () async {
        final milk = await planned('Milk', 2000, groceries);

        final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);

        final items = await trips.getItems(trip.id);
        expect(items, hasLength(1));
        expect(items.single.kind, ShoppingItemKind.planned);
        expect(items.single.transactionId, milk.id);
        expect(items.single.unitPriceMinor, 2000);
        expect(items.single.inCart, isFalse);
        final tx = (await services.transactions.byId(milk.id))!;
        expect(tx.status, TxStatus.planned);
        expect(tx.amountMinor, 2000);
      },
    );

    test('allows only one active trip at a time', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);

      expect(
        () => trips.startTrip(plannedTransactionIds: [milk.id]),
        throwsStateError,
      );

      await trips.cancelTrip(trip.id);
      expect(await trips.getActive(), isNull);
      expect(
        (await trips.startTrip(plannedTransactionIds: [milk.id])).isActive,
        isTrue,
      );
    });

    test('rejects an empty trip', () async {
      expect(() => trips.startTrip(), throwsArgumentError);
    });

    test('leaves out transactions that are not planned expenses', () async {
      final milk = await planned('Milk', 2000, groceries);
      await services.transactions.confirm(milk.id);

      expect(
        () => trips.startTrip(plannedTransactionIds: [milk.id]),
        throwsArgumentError,
      );
      expect(await trips.getActive(), isNull);
    });

    test('brings wishlist items along as planned lines', () async {
      final shoes = await services.wishlist.create(
        name: 'Shoes',
        estimatedPriceMinor: 30000,
      );

      final trip = await trips.startTrip(
        wishlistPicks: [
          WishlistPick(wishlistItemId: shoes.id, categoryId: clothes.id),
        ],
      );

      final item = (await trips.getItems(trip.id)).single;
      expect(item.kind, ShoppingItemKind.wishlist);
      expect(item.isImpulse, isFalse);
      expect(item.unitPriceMinor, 30000);
      expect(item.categoryId, clothes.id);
    });
  });

  group('cart', () {
    test('impulse lines go straight into the cart', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);

      final sweets = await trips.addImpulse(
        tripId: trip.id,
        name: 'Sweets',
        unitPriceMinor: 600,
        quantity: 2,
        categoryId: groceries.id,
      );

      expect(sweets.isImpulse, isTrue);
      expect(sweets.inCart, isTrue);
      expect(sweets.lineTotalMinor, 1200);
    });

    test('removing a line is undoable', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      final item = (await trips.getItems(trip.id)).single;

      await trips.removeItem(item.id);
      expect(await trips.getItems(trip.id), isEmpty);

      await trips.restoreItem(item.id);
      expect(await trips.getItems(trip.id), hasLength(1));
    });

    test('quantity never drops below one', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      final item = (await trips.getItems(trip.id)).single;

      await trips.updateItem(item.id, quantity: 0);

      expect((await trips.getItems(trip.id)).single.quantity, 1);
    });
  });

  group('checkout', () {
    test('flips planned transactions in place with the final total', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      final item = (await trips.getItems(trip.id)).single;
      await trips.updateItem(item.id, inCart: true, quantity: 3);
      final before = await transactionCount();

      final result = await trips.checkout(
        tripId: trip.id,
        accountId: accountId,
      );

      expect(await transactionCount(), before);
      expect(result.flipped, hasLength(1));
      expect(result.created, isEmpty);
      expect(result.totalMinor, 6000);
      final tx = (await services.transactions.byId(milk.id))!;
      expect(tx.status, TxStatus.confirmed);
      expect(tx.amountMinor, 6000);
      expect(tx.description, '3 × K20.00');
      expect(await trips.getActive(), isNull);
    });

    test(
      'keeps an existing description and appends the quantity note',
      () async {
        final milk = await planned(
          'Milk',
          2000,
          groceries,
          description: 'Fresh',
        );
        final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
        final item = (await trips.getItems(trip.id)).single;
        await trips.updateItem(item.id, inCart: true, quantity: 2);

        await trips.checkout(tripId: trip.id, accountId: accountId);

        expect(
          (await services.transactions.byId(milk.id))!.description,
          'Fresh · 2 × K20.00',
        );
      },
    );

    test('uses the edited price and adds no note for a single unit', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      final item = (await trips.getItems(trip.id)).single;
      await trips.updateItem(item.id, inCart: true, unitPriceMinor: 2250);

      await trips.checkout(tripId: trip.id, accountId: accountId);

      final tx = (await services.transactions.byId(milk.id))!;
      expect(tx.amountMinor, 2250);
      expect(tx.description, isNull);
    });

    test(
      'leaves planned lines that are not in the cart exactly as they were',
      () async {
        final milk = await planned('Milk', 2000, groceries);
        final rice = await planned('Rice', 5000, groceries);
        final trip = await trips.startTrip(
          plannedTransactionIds: [milk.id, rice.id],
        );
        final items = await trips.getItems(trip.id);
        await trips.updateItem(items.first.id, inCart: true);

        final result = await trips.checkout(
          tripId: trip.id,
          accountId: accountId,
        );

        expect(result.flipped, hasLength(1));
        final untouched = (await services.transactions.byId(rice.id))!;
        expect(untouched.status, TxStatus.planned);
        expect(untouched.amountMinor, 5000);
      },
    );

    test('creates a new expense for impulse lines and marks them', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      await trips.addImpulse(
        tripId: trip.id,
        name: 'Sweets',
        unitPriceMinor: 600,
        quantity: 2,
        categoryId: groceries.id,
      );
      final before = await transactionCount();

      final result = await trips.checkout(
        tripId: trip.id,
        accountId: accountId,
      );

      expect(await transactionCount(), before + 1);
      expect(result.created, hasLength(1));
      expect(result.impulseMinor, 1200);
      final created =
          (await services.transactions.watchByStatus(TxStatus.confirmed).first)
              .single;
      expect(created.merchant, 'Sweets');
      expect(created.amountMinor, 1200);
      expect(created.description, '2 × K6.00');
      expect(created.categoryId, groceries.id);
      expect(created.accountId, accountId);
      expect(created.metadata['shoppingTripId'], trip.id);
    });

    test('buys wishlist items through the wishlist', () async {
      final shoes = await services.wishlist.create(
        name: 'Shoes',
        estimatedPriceMinor: 30000,
      );
      final trip = await trips.startTrip(
        wishlistPicks: [
          WishlistPick(wishlistItemId: shoes.id, categoryId: clothes.id),
        ],
      );
      final item = (await trips.getItems(trip.id)).single;
      await trips.updateItem(item.id, inCart: true, unitPriceMinor: 28000);

      final result = await trips.checkout(
        tripId: trip.id,
        accountId: accountId,
      );

      expect(result.created, hasLength(1));
      final bought = (await services.wishlist.byId(shoes.id))!;
      expect(bought.status, WishlistItemStatus.purchased);
      expect(bought.actualPriceMinor, 28000);
      final tx = (await services.transactions.byId(
        bought.linkedTransactionId!,
      ))!;
      expect(tx.amountMinor, 28000);
      expect(tx.categoryId, clothes.id);
      expect(tx.status, TxStatus.confirmed);
    });

    test('skips a planned line that was paid elsewhere mid-trip', () async {
      final milk = await planned('Milk', 2000, groceries);
      final bread = await planned('Bread', 1500, groceries);
      final trip = await trips.startTrip(
        plannedTransactionIds: [milk.id, bread.id],
      );
      for (final item in await trips.getItems(trip.id)) {
        await trips.updateItem(item.id, inCart: true);
      }
      await services.transactions.updateFields(milk.id, amountMinor: 2100);
      await services.transactions.confirm(milk.id);

      final result = await trips.checkout(
        tripId: trip.id,
        accountId: accountId,
      );

      expect(result.skipped.single.reason, SkipReason.changedElsewhere);
      expect(result.skipped.single.item.name, 'Milk');
      expect(result.flipped.single.name, 'Bread');
      expect(result.totalMinor, 1500);
      expect((await services.transactions.byId(milk.id))!.amountMinor, 2100);
    });

    test('skips cart lines that still have no price', () async {
      final shoes = await services.wishlist.create(name: 'Shoes');
      final trip = await trips.startTrip(
        wishlistPicks: [WishlistPick(wishlistItemId: shoes.id)],
      );
      final item = (await trips.getItems(trip.id)).single;
      await trips.updateItem(item.id, inCart: true);

      final result = await trips.checkout(
        tripId: trip.id,
        accountId: accountId,
      );

      expect(result.skipped.single.reason, SkipReason.noPrice);
      expect(
        (await services.wishlist.byId(shoes.id))!.status,
        WishlistItemStatus.idea,
      );
    });

    test('cannot be run twice', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      final item = (await trips.getItems(trip.id)).single;
      await trips.updateItem(item.id, inCart: true);
      await trips.checkout(tripId: trip.id, accountId: accountId);

      expect(
        () => trips.checkout(tripId: trip.id, accountId: accountId),
        throwsStateError,
      );
    });
  });

  group('cancelTrip', () {
    test('leaves the ledger exactly as it was', () async {
      final milk = await planned('Milk', 2000, groceries);
      final trip = await trips.startTrip(plannedTransactionIds: [milk.id]);
      final item = (await trips.getItems(trip.id)).single;
      await trips.updateItem(item.id, inCart: true, quantity: 4);
      await trips.addImpulse(
        tripId: trip.id,
        name: 'Sweets',
        unitPriceMinor: 600,
      );
      final before = await transactionCount();

      await trips.cancelTrip(trip.id);

      expect(await transactionCount(), before);
      final tx = (await services.transactions.byId(milk.id))!;
      expect(tx.status, TxStatus.planned);
      expect(tx.amountMinor, 2000);
      expect(await trips.getActive(), isNull);
    });
  });

  group('envelopes', () {
    test('mirror the budget screen: rolled up, confirmed only', () async {
      final fruit = await services.categories.create(
        'Fruit',
        parentId: groceries.id,
      );
      final period = await services.budgetPeriods.ensurePeriodContaining(
        DateTime.now(),
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: groceries.id,
        amountMinor: 20000,
      );
      Future<void> spend(String categoryId, int amount, TxStatus status) =>
          services.transactions.insertDraft(
            TransactionDraft(
              amountMinor: amount,
              direction: TxDirection.debit,
              source: TxSource.manual,
              transactedAt: DateTime.now(),
              categoryId: categoryId,
            ),
            accountId: accountId,
            idempotencyKey: 'test:${Ids.newId()}',
            status: status,
          );
      await spend(groceries.id, 3000, TxStatus.confirmed);
      await spend(fruit.id, 2000, TxStatus.confirmed);
      await spend(groceries.id, 9999, TxStatus.planned);

      final envelopes = await services.categoryEnvelopes.forPeriod(period);

      expect(envelopes[groceries.id]!.envelopeMinor, 20000);
      expect(envelopes[groceries.id]!.spentMinor, 5000);
      expect(envelopes[clothes.id]!.envelopeMinor, isNull);
      expect(envelopes.containsKey(fruit.id), isFalse);
    });
  });

  test('the K500 example: K440 spent, K60 left, K60 impulse', () async {
    final food = await services.categories.create('Food shop');
    final accessories = await services.categories.create('Accessories');
    final period = await services.budgetPeriods.ensurePeriodContaining(
      DateTime.now(),
    );
    for (final (category, amount) in [
      (food, 24000),
      (clothes, 12000),
      (accessories, 14000),
    ]) {
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: category.id,
        amountMinor: amount,
      );
    }
    final groceriesTx = await planned('Groceries', 18000, food);
    final shirt = await planned('Clothes', 12000, clothes);
    final case_ = await planned('Phone accessories', 8000, accessories);
    final trip = await trips.startTrip(
      plannedTransactionIds: [groceriesTx.id, shirt.id, case_.id],
    );
    for (final item in await trips.getItems(trip.id)) {
      await trips.updateItem(item.id, inCart: true);
    }
    await trips.addImpulse(
      tripId: trip.id,
      name: 'Impulse purchase',
      unitPriceMinor: 6000,
      categoryId: food.id,
    );

    final summary = ShoppingTripCalculator.summarize(
      items: await trips.getItems(trip.id),
      envelopes: await services.categoryEnvelopes.forPeriod(period),
      categoriesById: {
        for (final c in await services.categories.getAll()) c.id: c,
      },
    );

    expect(summary.cartTotalMinor, 44000);
    expect(summary.impulseMinor, 6000);
    expect(summary.budgetMinor, 50000);
    expect(summary.leftMinor, 6000);
    expect(summary.isOver, isFalse);
  });
}
