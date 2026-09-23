import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/wishlist/cubit/cubit.dart';

void main() {
  group('WishlistState totals', () {
    test('splits by status and excludes purchased items from the '
        'outstanding total', () {
      final state = WishlistState(
        items: [
          const WishlistItem(id: '1', name: 'Idea A', estimatedPriceMinor: 100000),
          const WishlistItem(id: '2', name: 'Idea B'), // no price set
          const WishlistItem(
            id: '3',
            name: 'Saving toward it',
            estimatedPriceMinor: 200000,
            linkedGoalId: 'goal-1',
          ),
          WishlistItem(
            id: '4',
            name: 'Already bought',
            estimatedPriceMinor: 50000,
            actualPriceMinor: 45000,
            purchasedAt: DateTime(2026, 9, 1),
          ),
        ],
      );

      expect(state.ideaItems, hasLength(2));
      expect(state.savingItems, hasLength(1));
      expect(state.purchasedItems, hasLength(1));

      expect(state.ideaTotalMinor, 100000);
      expect(state.savingTotalMinor, 200000);
      expect(state.purchasedTotalMinor, 45000);

      expect(
        state.outstandingTotalMinor,
        300000,
        reason: 'idea + saving only — the purchased item already turned '
            'into real spend elsewhere',
      );
    });

    test('purchased total falls back to the estimate when no actual price '
        'was ever recorded', () {
      final state = WishlistState(
        items: [
          WishlistItem(
            id: '1',
            name: 'Bought without a recorded price',
            estimatedPriceMinor: 30000,
            purchasedAt: DateTime(2026, 9, 1),
          ),
        ],
      );

      expect(state.purchasedTotalMinor, 30000);
    });

    test('an item with no price at all contributes zero, not a crash', () {
      const state = WishlistState(
        items: [WishlistItem(id: '1', name: 'No price yet')],
      );

      expect(state.outstandingTotalMinor, 0);
      expect(state.ideaTotalMinor, 0);
    });
  });
}
