import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// A wishlist item chosen for a trip, with the category it should be
/// bought under and the price to start from.
class WishlistPick extends Equatable {
  const WishlistPick({
    required this.wishlistItemId,
    this.categoryId,
    this.priceMinor,
  });

  final String wishlistItemId;
  final String? categoryId;

  /// Overrides the wishlist item's estimate. Both null means the price
  /// still has to be entered in the shop.
  final int? priceMinor;

  @override
  List<Object?> get props => [wishlistItemId, categoryId, priceMinor];
}

enum SkipReason {
  /// The planned transaction was deleted, or is no longer planned
  /// (paid or edited elsewhere during the trip).
  changedElsewhere,

  /// The wishlist item was deleted or already bought.
  wishlistGone,

  /// The cart line has no price.
  noPrice,
}

class SkippedItem extends Equatable {
  const SkippedItem(this.item, this.reason);

  final ShoppingTripItem item;
  final SkipReason reason;

  @override
  List<Object?> get props => [item, reason];
}

class CheckoutResult extends Equatable {
  const CheckoutResult({
    required this.tripId,
    required this.flipped,
    required this.created,
    required this.skipped,
    required this.totalMinor,
    required this.impulseMinor,
  });

  final String tripId;

  /// Planned transactions turned into paid expenses in place.
  final List<ShoppingTripItem> flipped;

  /// New expenses: impulse lines and wishlist purchases.
  final List<ShoppingTripItem> created;
  final List<SkippedItem> skipped;

  /// What was actually written to the ledger.
  final int totalMinor;
  final int impulseMinor;

  @override
  List<Object?> get props => [
    tripId,
    flipped,
    created,
    skipped,
    totalMinor,
    impulseMinor,
  ];
}

/// Shopping trips and their cart.
///
/// Nothing here touches a planned transaction until [checkout]: during a
/// trip the cart only points at it. That makes cancelling free, and means
/// an unbought planned item is exactly as it was before the trip.
class ShoppingTripRepository {
  ShoppingTripRepository(
    this._db, {
    required this.userId,
    required TransactionRepository transactions,
    required WishlistRepository wishlist,
    required BudgetPeriodRepository budgetPeriods,
  }) : _transactions = transactions,
       _wishlist = wishlist,
       _budgetPeriods = budgetPeriods;

  final AppDatabase _db;
  final String userId;
  final TransactionRepository _transactions;
  final WishlistRepository _wishlist;
  final BudgetPeriodRepository _budgetPeriods;

  static ShoppingTrip _tripFromRow(ShoppingTripRow row) => ShoppingTrip(
    id: row.id,
    periodId: row.periodId,
    status: ShoppingTripStatus.fromDbName(row.status),
    startedAt: Iso.toDateTime(row.startedAt),
    finishedAt: row.finishedAt == null ? null : Iso.toDateTime(row.finishedAt!),
  );

  static ShoppingTripItem _itemFromRow(ShoppingTripItemRow row) =>
      ShoppingTripItem(
        id: row.id,
        tripId: row.tripId,
        kind: ShoppingItemKind.fromDbName(row.kind),
        transactionId: row.transactionId,
        wishlistItemId: row.wishlistItemId,
        name: row.name,
        categoryId: row.categoryId,
        plannedPriceMinor: row.plannedPriceMinor,
        unitPriceMinor: row.unitPriceMinor,
        quantity: row.quantity,
        inCart: row.inCart,
        sortOrder: row.sortOrder,
      );

  SimpleSelectStatement<$ShoppingTripsTable, ShoppingTripRow> _activeQuery() =>
      _db.select(_db.shoppingTrips)..where(
        (t) =>
            t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.status.equals(ShoppingTripStatus.active.name),
      );

  Future<ShoppingTrip?> getActive() async {
    final row = await (_activeQuery()..limit(1)).getSingleOrNull();
    return row == null ? null : _tripFromRow(row);
  }

  Stream<ShoppingTrip?> watchActive() {
    return (_activeQuery()..limit(1)).watchSingleOrNull().map(
      (row) => row == null ? null : _tripFromRow(row),
    );
  }

  SimpleSelectStatement<$ShoppingTripItemsTable, ShoppingTripItemRow>
  _itemsQuery(String tripId) => _db.select(_db.shoppingTripItems)
    ..where(
      (i) =>
          i.userId.equals(userId) &
          i.tripId.equals(tripId) &
          i.deletedAt.isNull(),
    )
    ..orderBy([
      (i) => OrderingTerm.asc(i.sortOrder),
      (i) => OrderingTerm.asc(i.createdAt),
    ]);

  Future<List<ShoppingTripItem>> getItems(String tripId) async =>
      (await _itemsQuery(tripId).get()).map(_itemFromRow).toList();

  Stream<List<ShoppingTripItem>> watchItems(String tripId) => _itemsQuery(
    tripId,
  ).watch().map((rows) => rows.map(_itemFromRow).toList());

  /// Starts a trip from the chosen planned expenses and wishlist items.
  /// Throws [StateError] if a trip is already active and
  /// [ArgumentError] if nothing was chosen. Planned ids that are no
  /// longer planned expenses are quietly left out.
  Future<ShoppingTrip> startTrip({
    List<String> plannedTransactionIds = const [],
    List<WishlistPick> wishlistPicks = const [],
  }) async {
    if (plannedTransactionIds.isEmpty && wishlistPicks.isEmpty) {
      throw ArgumentError('Pick at least one item to start a trip.');
    }
    return _db.transaction(() async {
      if (await getActive() != null) {
        throw StateError('A shopping trip is already active.');
      }
      final now = Iso.nowUtc();
      final period = await _budgetPeriods.ensurePeriodContaining(
        DateTime.now(),
      );
      final tripId = Ids.newId();
      await _db
          .into(_db.shoppingTrips)
          .insert(
            ShoppingTripsCompanion.insert(
              id: tripId,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              periodId: period.id,
              startedAt: now,
            ),
          );

      var order = 0;
      for (final txId in plannedTransactionIds) {
        final tx = await _liveTransaction(txId);
        if (tx == null ||
            tx.status != TxStatus.planned.dbName ||
            tx.direction != TxDirection.debit.name) {
          continue;
        }
        await _insertItem(
          tripId: tripId,
          kind: ShoppingItemKind.planned,
          name: tx.merchant ?? tx.description ?? 'Planned item',
          unitPriceMinor: tx.amountMinor,
          plannedPriceMinor: tx.amountMinor,
          categoryId: tx.categoryId,
          transactionId: tx.id,
          sortOrder: order++,
        );
      }
      for (final pick in wishlistPicks) {
        final item = await _wishlist.byId(pick.wishlistItemId);
        if (item == null || item.purchasedAt != null) continue;
        final price = pick.priceMinor ?? item.estimatedPriceMinor ?? 0;
        await _insertItem(
          tripId: tripId,
          kind: ShoppingItemKind.wishlist,
          name: item.name,
          unitPriceMinor: price,
          plannedPriceMinor: price > 0 ? price : null,
          categoryId: pick.categoryId,
          wishlistItemId: item.id,
          sortOrder: order++,
        );
      }
      if (order == 0) {
        throw ArgumentError('None of the chosen items can be bought.');
      }
      return (await getActive())!;
    });
  }

  /// Adds something that was not on the list. It goes straight into
  /// the cart.
  Future<ShoppingTripItem> addImpulse({
    required String tripId,
    required String name,
    required int unitPriceMinor,
    int quantity = 1,
    String? categoryId,
  }) async {
    final order = await _nextSortOrder(tripId);
    final id = await _insertItem(
      tripId: tripId,
      kind: ShoppingItemKind.impulse,
      name: name,
      unitPriceMinor: unitPriceMinor,
      quantity: quantity,
      categoryId: categoryId,
      inCart: true,
      sortOrder: order,
    );
    return _itemFromRow(await _requireItemRow(id));
  }

  Future<void> updateItem(
    String itemId, {
    String? name,
    int? unitPriceMinor,
    int? quantity,
    String? categoryId,
    bool clearCategory = false,
    bool? inCart,
  }) async {
    await (_db.update(
      _db.shoppingTripItems,
    )..where((i) => i.id.equals(itemId))).write(
      ShoppingTripItemsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        unitPriceMinor: unitPriceMinor == null
            ? const Value.absent()
            : Value(unitPriceMinor),
        quantity: quantity == null
            ? const Value.absent()
            : Value(quantity < 1 ? 1 : quantity),
        categoryId: clearCategory
            ? const Value(null)
            : (categoryId == null ? const Value.absent() : Value(categoryId)),
        inCart: inCart == null ? const Value.absent() : Value(inCart),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  /// Takes the line off the trip entirely. [restoreItem] brings it
  /// back, for undo.
  Future<void> removeItem(String itemId) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.shoppingTripItems,
    )..where((i) => i.id.equals(itemId))).write(
      ShoppingTripItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> restoreItem(String itemId) async {
    await (_db.update(
      _db.shoppingTripItems,
    )..where((i) => i.id.equals(itemId))).write(
      ShoppingTripItemsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  /// Ends the trip without writing anything to the ledger. Planned
  /// transactions were never changed, so there is nothing to undo.
  Future<void> cancelTrip(String tripId) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.shoppingTrips,
    )..where((t) => t.id.equals(tripId) & t.status.equals('active'))).write(
      ShoppingTripsCompanion(
        status: Value(ShoppingTripStatus.cancelled.name),
        finishedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Turns the cart into real expenses, all or nothing.
  ///
  /// * A planned line flips its existing transaction to confirmed with
  ///   the final total, dated now, with "3 × K20.00" appended to its
  ///   description when the quantity is above one. It keeps its own
  ///   account.
  /// * A wishlist line is bought through the wishlist, which marks the
  ///   item purchased.
  /// * An impulse line creates a new expense on [accountId].
  ///
  /// Planned lines not in the cart are left alone. Lines that can no
  /// longer be written (deleted or paid elsewhere, no price) come back
  /// in [CheckoutResult.skipped] instead of failing the whole checkout.
  Future<CheckoutResult> checkout({
    required String tripId,
    required String accountId,
    DateTime? now,
  }) {
    return _db.transaction(() async {
      final tripRow =
          await (_db.select(_db.shoppingTrips)
                ..where((t) => t.id.equals(tripId) & t.userId.equals(userId)))
              .getSingleOrNull();
      if (tripRow == null || tripRow.status != 'active') {
        throw StateError('That shopping trip is not active.');
      }
      final when = now ?? DateTime.now();
      final period = await _budgetPeriods.ensurePeriodContaining(when);
      final cart = (await getItems(tripId)).where((i) => i.inCart).toList();

      final flipped = <ShoppingTripItem>[];
      final created = <ShoppingTripItem>[];
      final skipped = <SkippedItem>[];
      var total = 0;
      var impulse = 0;

      for (final item in cart) {
        if (item.unitPriceMinor <= 0) {
          skipped.add(SkippedItem(item, SkipReason.noPrice));
          continue;
        }
        final note = item.quantity > 1
            ? '${item.quantity} × ${Money.display(item.unitPriceMinor)}'
            : null;

        switch (item.kind) {
          case ShoppingItemKind.planned:
            final tx = item.transactionId == null
                ? null
                : await _liveTransaction(item.transactionId!);
            if (tx == null || tx.status != TxStatus.planned.dbName) {
              skipped.add(SkippedItem(item, SkipReason.changedElsewhere));
              continue;
            }
            await _transactions.updateFields(
              tx.id,
              status: TxStatus.confirmed,
              amountMinor: item.lineTotalMinor,
              transactedAt: when,
              categoryId: item.categoryId,
              description: _withNote(tx.description, note),
              periodId: period.id,
            );
            flipped.add(item);
          case ShoppingItemKind.wishlist:
            final wish = item.wishlistItemId == null
                ? null
                : await _wishlist.byId(item.wishlistItemId!);
            if (wish == null || wish.purchasedAt != null) {
              skipped.add(SkippedItem(item, SkipReason.wishlistGone));
              continue;
            }
            final tx = await _wishlist.convertToExpense(
              wish.id,
              accountId: accountId,
              amountMinor: item.lineTotalMinor,
              transactedAt: when,
              categoryId: item.categoryId,
            );
            if (note != null) {
              await _transactions.updateFields(tx.id, description: note);
            }
            await _linkTransaction(item.id, tx.id);
            created.add(item);
          case ShoppingItemKind.impulse:
            final tx = await _transactions.insertDraft(
              TransactionDraft(
                amountMinor: item.lineTotalMinor,
                direction: TxDirection.debit,
                source: TxSource.manual,
                transactedAt: when,
                merchant: item.name,
                description: note,
                categoryId: item.categoryId,
                confidence: 1,
                metadata: {'shoppingTripId': tripId, 'impulse': true},
              ),
              accountId: accountId,
              idempotencyKey: 'shopping:${item.id}',
              status: TxStatus.confirmed,
              periodId: period.id,
            );
            await _linkTransaction(item.id, tx.id);
            created.add(item);
            impulse += item.lineTotalMinor;
        }
        total += item.lineTotalMinor;
      }

      final stamp = Iso.nowUtc();
      await (_db.update(
        _db.shoppingTrips,
      )..where((t) => t.id.equals(tripId))).write(
        ShoppingTripsCompanion(
          status: Value(ShoppingTripStatus.completed.name),
          finishedAt: Value(stamp),
          updatedAt: Value(stamp),
        ),
      );

      return CheckoutResult(
        tripId: tripId,
        flipped: flipped,
        created: created,
        skipped: skipped,
        totalMinor: total,
        impulseMinor: impulse,
      );
    });
  }

  static String? _withNote(String? existing, String? note) {
    if (note == null) return existing;
    if (existing == null || existing.trim().isEmpty) return note;
    if (existing.contains(note)) return existing;
    return '$existing · $note';
  }

  Future<TransactionRow?> _liveTransaction(String id) {
    return (_db.select(_db.transactions)..where(
          (t) =>
              t.id.equals(id) & t.userId.equals(userId) & t.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<void> _linkTransaction(String itemId, String transactionId) async {
    await (_db.update(
      _db.shoppingTripItems,
    )..where((i) => i.id.equals(itemId))).write(
      ShoppingTripItemsCompanion(
        transactionId: Value(transactionId),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  Future<ShoppingTripItemRow> _requireItemRow(String id) => (_db.select(
    _db.shoppingTripItems,
  )..where((i) => i.id.equals(id))).getSingle();

  Future<int> _nextSortOrder(String tripId) async {
    final rows = await _itemsQuery(tripId).get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<String> _insertItem({
    required String tripId,
    required ShoppingItemKind kind,
    required String name,
    required int unitPriceMinor,
    required int sortOrder,
    int? plannedPriceMinor,
    int quantity = 1,
    String? categoryId,
    String? transactionId,
    String? wishlistItemId,
    bool inCart = false,
  }) async {
    final id = Ids.newId();
    final now = Iso.nowUtc();
    await _db
        .into(_db.shoppingTripItems)
        .insert(
          ShoppingTripItemsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            tripId: tripId,
            kind: kind.name,
            name: name,
            unitPriceMinor: unitPriceMinor,
            transactionId: Value(transactionId),
            wishlistItemId: Value(wishlistItemId),
            categoryId: Value(categoryId),
            plannedPriceMinor: Value(plannedPriceMinor),
            quantity: Value(quantity < 1 ? 1 : quantity),
            inCart: Value(inCart),
            sortOrder: Value(sortOrder),
          ),
        );
    return id;
  }
}
