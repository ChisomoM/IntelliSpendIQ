import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';

void main() {
  const groceries = Category(id: 'groceries', name: 'Groceries');
  const clothes = Category(id: 'clothes', name: 'Clothes');
  const accessories = Category(id: 'accessories', name: 'Accessories');
  const fruit = Category(id: 'fruit', name: 'Fruit', parentId: 'groceries');
  final categories = {
    for (final c in [groceries, clothes, accessories, fruit]) c.id: c,
  };

  Map<String, CategoryEnvelope> envelopes({int groceriesSpent = 0}) => {
    'groceries': CategoryEnvelope(
      categoryId: 'groceries',
      envelopeMinor: 20000,
      spentMinor: groceriesSpent,
    ),
    'clothes': const CategoryEnvelope(
      categoryId: 'clothes',
      envelopeMinor: 15000,
    ),
    'accessories': const CategoryEnvelope(
      categoryId: 'accessories',
      envelopeMinor: 10000,
    ),
    'entertainment': const CategoryEnvelope(
      categoryId: 'entertainment',
      envelopeMinor: 5000,
    ),
  };

  ShoppingTripItem item(
    String id,
    ShoppingItemKind kind,
    String? categoryId,
    int unit, {
    int qty = 1,
    bool inCart = true,
  }) => ShoppingTripItem(
    id: id,
    tripId: 't',
    kind: kind,
    name: id,
    categoryId: categoryId,
    unitPriceMinor: unit,
    quantity: qty,
    inCart: inCart,
  );

  TripSummary summarize(
    List<ShoppingTripItem> items, {
    Map<String, CategoryEnvelope>? env,
  }) => ShoppingTripCalculator.summarize(
    items: items,
    envelopes: env ?? envelopes(),
    categoriesById: categories,
  );

  group('summarize', () {
    test('tracks spend, budget, remaining and impulse for a normal trip', () {
      final summary = summarize([
        item('milk', ShoppingItemKind.planned, 'groceries', 18000),
        item('shirt', ShoppingItemKind.planned, 'clothes', 12000),
        item('cable', ShoppingItemKind.planned, 'accessories', 8000),
        item('sweets', ShoppingItemKind.impulse, 'groceries', 600),
      ]);

      expect(summary.cartTotalMinor, 38600);
      expect(summary.impulseMinor, 600);
      expect(summary.impulseShare, closeTo(600 / 38600, 1e-9));
      expect(summary.budgetMinor, 45000);
      // Groceries 20000-18600, Clothes 15000-12000, Accessories 10000-8000.
      expect(summary.leftMinor, 1400 + 3000 + 2000);
      expect(summary.isOver, isFalse);
      expect(summary.toBuyMinor, 0);
    });

    test('a category is over only when its own envelope is exceeded', () {
      final summary = summarize([
        item('shirts', ShoppingItemKind.planned, 'clothes', 9000, qty: 2),
        item('cable', ShoppingItemKind.planned, 'accessories', 1000),
      ]);

      final clothesLine = summary.lineFor('clothes')!;
      expect(clothesLine.isOver, isTrue);
      expect(clothesLine.overByMinor, 3000);
      expect(summary.lineFor('accessories')!.isOver, isFalse);
      expect(summary.overByMinor, 3000);
      expect(summary.isOver, isTrue);
      // Accessories' slack does not cancel Clothes' overspend.
      expect(summary.leftMinor, 9000);
    });

    test('rolls subcategories into the parent envelope', () {
      final summary = summarize([
        item('apples', ShoppingItemKind.planned, 'fruit', 5000),
        item('bread', ShoppingItemKind.planned, 'groceries', 4000),
      ]);

      expect(summary.lines, hasLength(1));
      expect(summary.lineFor('groceries')!.cartMinor, 9000);
    });

    test('spend before the trip uses up room', () {
      final summary = summarize([
        item('milk', ShoppingItemKind.planned, 'groceries', 5000),
      ], env: envelopes(groceriesSpent: 18000));

      final line = summary.lineFor('groceries')!;
      expect(line.roomMinor, 2000);
      expect(line.leftMinor, -3000);
      expect(line.isOver, isTrue);
      expect(summary.budgetMinor, 2000);
    });

    test('planned lines not yet in the cart count as still to buy', () {
      final summary = summarize([
        item('milk', ShoppingItemKind.planned, 'groceries', 5000),
        item(
          'rice',
          ShoppingItemKind.planned,
          'groceries',
          2000,
          qty: 3,
          inCart: false,
        ),
      ]);

      expect(summary.toBuyMinor, 6000);
      final line = summary.lineFor('groceries')!;
      expect(line.leftMinor, 15000);
      expect(line.freeMinor, 9000);
    });

    test('impulse in a category off the list stays off the trip budget', () {
      final summary = summarize([
        item('milk', ShoppingItemKind.planned, 'groceries', 5000),
        item('movie', ShoppingItemKind.impulse, 'entertainment', 2000),
      ]);

      expect(summary.budgetMinor, 20000);
      expect(summary.leftMinor, 15000);
      expect(summary.lineFor('entertainment')!.onList, isFalse);
      expect(summary.lineFor('entertainment')!.leftMinor, 3000);
      expect(summary.cartTotalMinor, 7000);
      expect(summary.impulseMinor, 2000);
    });

    test('items without a category or envelope can never be over', () {
      final summary = summarize([
        item('misc', ShoppingItemKind.impulse, null, 999999),
      ]);

      expect(summary.isOver, isFalse);
      expect(summary.lineFor(null)!.hasBudget, isFalse);
      expect(summary.cartTotalMinor, 999999);
    });

    test('warns near the limit only when the cart has put it there', () {
      final near = summarize([
        item('shirt', ShoppingItemKind.planned, 'clothes', 12500),
      ]);
      expect(near.lineFor('clothes')!.severity, TripSeverity.near);

      // Already at 90% before the trip, but nothing from it is in the
      // cart yet: no alert until the shopper adds something.
      final quiet = summarize([
        item(
          'milk',
          ShoppingItemKind.planned,
          'groceries',
          1000,
          inCart: false,
        ),
      ], env: envelopes(groceriesSpent: 18000));
      expect(quiet.lineFor('groceries')!.severity, TripSeverity.ok);

      final added = summarize([
        item('milk', ShoppingItemKind.planned, 'groceries', 1000),
      ], env: envelopes(groceriesSpent: 18000));
      expect(added.lineFor('groceries')!.severity, TripSeverity.near);
    });
  });

  group('canAfford', () {
    final items = [
      item('shirt', ShoppingItemKind.planned, 'clothes', 12000),
      item(
        'trousers',
        ShoppingItemKind.planned,
        'clothes',
        2000,
        inCart: false,
      ),
    ];

    AffordAnswer ask(int price, {String? category = 'clothes', int qty = 1}) =>
        ShoppingTripCalculator.canAfford(
          items: items,
          envelopes: envelopes(),
          categoriesById: categories,
          unitPriceMinor: price,
          quantity: qty,
          categoryId: category,
        );

    test('yes when it fits and leaves room for the list', () {
      final answer = ask(500);
      expect(answer.verdict, AffordVerdict.yes);
      expect(answer.leftAfterMinor, 2500);
    });

    test('tight when it fits but squeezes what is still to buy', () {
      final answer = ask(2000);
      expect(answer.verdict, AffordVerdict.tight);
      expect(answer.shortForListMinor, 1000);
    });

    test('no when it would put the category over', () {
      final answer = ask(2000, qty: 2);
      expect(answer.verdict, AffordVerdict.no);
      expect(answer.overByMinor, 1000);
    });

    test('no budget when the category has no envelope', () {
      expect(ask(100, category: null).verdict, AffordVerdict.noBudget);
    });
  });
}
