import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/savings_goal_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/models/wishlist_item_photo.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Something the user wants but hasn't committed to yet — see
/// [WishlistItem] for why it stays out of every balance/budget/report
/// until it's converted. That conversion is this repository's other job:
/// [convertToGoal] hands off to [SavingsGoalRepository.create], and
/// [convertToExpense] hands off to [SavingsGoalRepository.spend] (when the
/// item is already funded by a goal) or [TransactionRepository.insertDraft]
/// directly (when it isn't) — reusing the same tested spend path Savings
/// Goals already has rather than re-deriving it.
class WishlistRepository {
  WishlistRepository(
    this._db, {
    required this.userId,
    required TransactionRepository transactions,
    required SavingsGoalRepository savingsGoals,
    required BudgetPeriodRepository budgetPeriods,
    Future<Directory> Function()? documentsDirectory,
  }) : _transactions = transactions,
       _savingsGoals = savingsGoals,
       _budgetPeriods = budgetPeriods,
       _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final String userId;
  final TransactionRepository _transactions;
  final SavingsGoalRepository _savingsGoals;
  final BudgetPeriodRepository _budgetPeriods;

  /// Defaults to `path_provider`'s documents directory; overridable so
  /// tests never need a platform channel just to write a file — same
  /// seam `TransactionEntryCubit` uses for receipt photos.
  final Future<Directory> Function() _documentsDirectory;

  static WishlistItem _fromRow(WishlistItemRow row) => WishlistItem(
    id: row.id,
    name: row.name,
    estimatedPriceMinor: row.estimatedPriceMinor,
    actualPriceMinor: row.actualPriceMinor,
    seenAt: row.seenAt,
    productUrl: row.productUrl,
    note: row.note,
    linkedGoalId: row.linkedGoalId,
    linkedTransactionId: row.linkedTransactionId,
    purchasedAt: row.purchasedAt == null ? null : Iso.toDateTime(row.purchasedAt!),
  );

  static WishlistItemPhoto _photoFromRow(WishlistItemPhotoRow row) =>
      WishlistItemPhoto(
        id: row.id,
        wishlistItemId: row.wishlistItemId,
        path: row.path,
        sortOrder: row.sortOrder,
      );

  Stream<List<WishlistItem>> watchAll() {
    final query = _db.select(_db.wishlistItems)
      ..where((w) => w.userId.equals(userId) & w.deletedAt.isNull())
      ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Stream<List<WishlistItemPhoto>> watchPhotos(String itemId) {
    final query = _db.select(_db.wishlistItemPhotos)
      ..where((ph) => ph.wishlistItemId.equals(itemId))
      ..orderBy([(ph) => OrderingTerm.asc(ph.sortOrder)]);
    return query.watch().map((rows) => rows.map(_photoFromRow).toList());
  }

  /// Each item's lowest-sort-order photo path, for the list's cover
  /// thumbnail. Reduced in Dart rather than a raw SQL aggregate — photo
  /// counts per item are small (capped in the UI), so there's no need
  /// for the query complexity a `MIN`-per-group would add.
  Stream<Map<String, String>> watchCovers() {
    final query = _db.select(_db.wishlistItemPhotos)
      ..orderBy([(ph) => OrderingTerm.asc(ph.sortOrder)]);
    return query.watch().map((rows) {
      final covers = <String, String>{};
      for (final row in rows) {
        covers.putIfAbsent(row.wishlistItemId, () => row.path);
      }
      return covers;
    });
  }

  Future<WishlistItem> create({
    required String name,
    int? estimatedPriceMinor,
    String? seenAt,
    String? productUrl,
    String? note,
  }) async {
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.wishlistItems)
        .insert(
          WishlistItemsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: name,
            estimatedPriceMinor: Value(estimatedPriceMinor),
            seenAt: Value(seenAt),
            productUrl: Value(productUrl),
            note: Value(note),
          ),
        );
    return WishlistItem(
      id: id,
      name: name,
      estimatedPriceMinor: estimatedPriceMinor,
      seenAt: seenAt,
      productUrl: productUrl,
      note: note,
    );
  }

  Future<void> updateFields(
    String id, {
    String? name,
    int? estimatedPriceMinor,
    bool clearEstimatedPrice = false,
    String? seenAt,
    bool clearSeenAt = false,
    String? productUrl,
    bool clearProductUrl = false,
    String? note,
    bool clearNote = false,
  }) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.wishlistItems,
    )..where((w) => w.id.equals(id))).write(
      WishlistItemsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        estimatedPriceMinor: clearEstimatedPrice
            ? const Value(null)
            : (estimatedPriceMinor == null
                  ? const Value.absent()
                  : Value(estimatedPriceMinor)),
        seenAt: clearSeenAt
            ? const Value(null)
            : (seenAt == null ? const Value.absent() : Value(seenAt)),
        productUrl: clearProductUrl
            ? const Value(null)
            : (productUrl == null ? const Value.absent() : Value(productUrl)),
        note: clearNote
            ? const Value(null)
            : (note == null ? const Value.absent() : Value(note)),
        updatedAt: Value(now),
      ),
    );
  }

  /// Copies [sourcePath] into app-local storage and attaches it as a
  /// photo — the same copy-then-store convention
  /// `TransactionEntryCubit.attachReceipt` uses for receipts, in its own
  /// `wishlist_photos/` subfolder.
  Future<WishlistItemPhoto> addPhoto(String itemId, String sourcePath) async {
    final documentsDir = await _documentsDirectory();
    final photosDir = Directory(p.join(documentsDir.path, 'wishlist_photos'));
    await photosDir.create(recursive: true);
    final extension = p.extension(sourcePath);
    final id = Ids.newId();
    final destination = p.join(photosDir.path, '$id$extension');
    await File(sourcePath).copy(destination);

    final existing = await (_db.select(
      _db.wishlistItemPhotos,
    )..where((ph) => ph.wishlistItemId.equals(itemId))).get();
    final sortOrder = existing.isEmpty
        ? 0
        : existing.map((ph) => ph.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    await _db
        .into(_db.wishlistItemPhotos)
        .insert(
          WishlistItemPhotosCompanion.insert(
            id: id,
            wishlistItemId: itemId,
            path: destination,
            sortOrder: Value(sortOrder),
            createdAt: Iso.nowUtc(),
          ),
        );
    return WishlistItemPhoto(
      id: id,
      wishlistItemId: itemId,
      path: destination,
      sortOrder: sortOrder,
    );
  }

  /// Deletes the photo's row and its file. No undo — a single photo
  /// removal isn't wrapped in the app's undo-snackbar pattern.
  Future<void> removePhoto(String photoId) async {
    final row = await (_db.select(
      _db.wishlistItemPhotos,
    )..where((ph) => ph.id.equals(photoId))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(
      _db.wishlistItemPhotos,
    )..where((ph) => ph.id.equals(photoId))).go();
    await _tryDeleteFile(row.path);
  }

  /// Turns the item into a funded [SavingsGoal]. The item stays on the
  /// list — it's never deleted by this — its status becomes `saving`
  /// because [WishlistItem.linkedGoalId] is now set.
  Future<SavingsGoal> convertToGoal(
    String itemId, {
    required int targetMinor,
    DateTime? targetDate,
    String? defaultAccountId,
  }) async {
    final item = await _requireItem(itemId);
    final goal = await _savingsGoals.create(
      name: item.name,
      targetMinor: targetMinor,
      targetDate: targetDate,
      defaultAccountId: defaultAccountId,
    );
    await (_db.update(_db.wishlistItems)..where((w) => w.id.equals(itemId)))
        .write(
          WishlistItemsCompanion(
            linkedGoalId: Value(goal.id),
            updatedAt: Value(Iso.nowUtc()),
          ),
        );
    return goal;
  }

  /// Buys the item: if it's already funded by a linked goal, releases
  /// that saving toward a real expense via
  /// [SavingsGoalRepository.spend] (handles partial/over funding for
  /// free); otherwise records the expense directly. Either way the item
  /// is marked purchased and pointed at the resulting transaction.
  Future<Transaction> convertToExpense(
    String itemId, {
    required String accountId,
    required int amountMinor,
    required DateTime transactedAt,
    String? categoryId,
  }) async {
    final item = await _requireItem(itemId);

    final Transaction tx;
    if (item.linkedGoalId != null) {
      tx = await _savingsGoals.spend(
        goalId: item.linkedGoalId!,
        accountId: accountId,
        amountMinor: amountMinor,
        transactedAt: transactedAt,
        categoryId: categoryId,
        merchant: item.name,
      );
    } else {
      final periodId = (await _budgetPeriods.ensurePeriodContaining(
        transactedAt,
      )).id;
      tx = await _transactions.insertDraft(
        TransactionDraft(
          amountMinor: amountMinor,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: transactedAt,
          merchant: item.name,
          categoryId: categoryId,
          metadata: {'linkedWishlistItemId': itemId},
        ),
        accountId: accountId,
        idempotencyKey: 'wishlist:$itemId:buy:${Ids.newId()}',
        status: TxStatus.confirmed,
        periodId: periodId,
      );
    }

    await (_db.update(_db.wishlistItems)..where((w) => w.id.equals(itemId)))
        .write(
          WishlistItemsCompanion(
            actualPriceMinor: Value(amountMinor),
            linkedTransactionId: Value(tx.id),
            purchasedAt: Value(Iso.fromDateTime(transactedAt)),
            updatedAt: Value(Iso.nowUtc()),
          ),
        );
    return tx;
  }

  /// Soft-deletes the item; hard-deletes its photos (rows and files) —
  /// nothing downstream ever needs an orphaned photo once its parent is
  /// gone. Never touches a linked goal: once promoted, a goal stands on
  /// its own.
  Future<void> delete(String id) async {
    final photos = await (_db.select(
      _db.wishlistItemPhotos,
    )..where((ph) => ph.wishlistItemId.equals(id))).get();
    await (_db.delete(
      _db.wishlistItemPhotos,
    )..where((ph) => ph.wishlistItemId.equals(id))).go();
    for (final photo in photos) {
      await _tryDeleteFile(photo.path);
    }

    final now = Iso.nowUtc();
    await (_db.update(_db.wishlistItems)..where((w) => w.id.equals(id))).write(
      WishlistItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<WishlistItem> _requireItem(String id) async {
    final row = await (_db.select(
      _db.wishlistItems,
    )..where((w) => w.id.equals(id))).getSingle();
    return _fromRow(row);
  }

  Future<void> _tryDeleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  // --- Backup export/import -------------------------------------------

  Future<List<WishlistItem>> getAllForExport() async {
    final query = _db.select(_db.wishlistItems)
      ..where((w) => w.userId.equals(userId))
      ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Every photo of every item this user owns, including deleted items'
  /// photos would already be gone by then — [delete] removes photo rows
  /// outright, so this only ever reflects live items.
  Future<List<WishlistItemPhoto>> getAllPhotosForExport() async {
    final itemIds = (await (_db.select(
      _db.wishlistItems,
    )..where((w) => w.userId.equals(userId))).get()).map((w) => w.id).toSet();
    if (itemIds.isEmpty) return const [];
    final query = _db.select(_db.wishlistItemPhotos)
      ..where((ph) => ph.wishlistItemId.isIn(itemIds))
      ..orderBy([(ph) => OrderingTerm.asc(ph.sortOrder)]);
    return (await query.get()).map(_photoFromRow).toList();
  }

  /// Re-inserts an item from a backup, preserving its original id.
  /// **Known limitation**: only the row is restored — the photo *files*
  /// referenced by [getAllPhotosForExport] aren't in the backup JSON, the
  /// same limitation `Transaction.receiptPath` already has.
  Future<bool> restoreItem(WishlistItem item) async {
    final existing = await (_db.select(
      _db.wishlistItems,
    )..where((w) => w.id.equals(item.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    await _db
        .into(_db.wishlistItems)
        .insert(
          WishlistItemsCompanion.insert(
            id: item.id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: item.name,
            estimatedPriceMinor: Value(item.estimatedPriceMinor),
            actualPriceMinor: Value(item.actualPriceMinor),
            seenAt: Value(item.seenAt),
            productUrl: Value(item.productUrl),
            note: Value(item.note),
            linkedGoalId: Value(item.linkedGoalId),
            linkedTransactionId: Value(item.linkedTransactionId),
            purchasedAt: Value(
              item.purchasedAt == null ? null : Iso.fromDateTime(item.purchasedAt!),
            ),
          ),
        );
    return true;
  }

  Future<bool> restorePhoto(WishlistItemPhoto photo) async {
    final existing = await (_db.select(
      _db.wishlistItemPhotos,
    )..where((ph) => ph.id.equals(photo.id))).getSingleOrNull();
    if (existing != null) return false;

    await _db
        .into(_db.wishlistItemPhotos)
        .insert(
          WishlistItemPhotosCompanion.insert(
            id: photo.id,
            wishlistItemId: photo.wishlistItemId,
            path: photo.path,
            sortOrder: Value(photo.sortOrder),
            createdAt: Iso.nowUtc(),
          ),
        );
    return true;
  }
}
