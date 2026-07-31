import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';

class TransferRepository {
  TransferRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static Transfer _fromRow(TransferRow row) => Transfer(
    id: row.id,
    fromAccountId: row.fromAccountId,
    toAccountId: row.toAccountId,
    amountMinor: row.amountMinor,
    transactedAt: Iso.toDateTime(row.transactedAt),
    note: row.note,
  );

  Stream<List<Transfer>> watchAll() {
    final query = _db.select(_db.transfers)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Every transfer, unbounded — for backups.
  Future<List<Transfer>> getAllForExport() async {
    final query = _db.select(_db.transfers)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Links two existing transaction legs — a debit on one account and
  /// a credit of the same amount on another — into a single [Transfer],
  /// then soft-deletes both legs. That soft-delete is what excludes
  /// them from every spend/income total: those aggregates already
  /// filter out deleted rows, so nothing else needs to change to keep
  /// a transfer from being counted as spend or income.
  Future<Transfer> linkTransfer({
    required Transaction fromTransaction,
    required Transaction toTransaction,
    String? note,
  }) async {
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db.transaction(() async {
      await _db
          .into(_db.transfers)
          .insert(
            TransfersCompanion.insert(
              id: id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              fromAccountId: fromTransaction.accountId,
              toAccountId: toTransaction.accountId,
              amountMinor: fromTransaction.amountMinor,
              transactedAt: Iso.fromDateTime(fromTransaction.transactedAt),
              note: Value(note),
              fromTransactionId: Value(fromTransaction.id),
              toTransactionId: Value(toTransaction.id),
            ),
          );
      for (final txId in [fromTransaction.id, toTransaction.id]) {
        await (_db.update(
          _db.transactions,
        )..where((t) => t.id.equals(txId))).write(
          TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
    });
    return Transfer(
      id: id,
      fromAccountId: fromTransaction.accountId,
      toAccountId: toTransaction.accountId,
      amountMinor: fromTransaction.amountMinor,
      transactedAt: fromTransaction.transactedAt,
      note: note,
    );
  }

  /// Re-inserts a transfer from a backup, preserving its original id
  /// so importing the same backup twice does not duplicate anything.
  Future<bool> restoreTransfer(Transfer transfer) async {
    final existing = await (_db.select(
      _db.transfers,
    )..where((t) => t.id.equals(transfer.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    await _db
        .into(_db.transfers)
        .insert(
          TransfersCompanion.insert(
            id: transfer.id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            fromAccountId: transfer.fromAccountId,
            toAccountId: transfer.toAccountId,
            amountMinor: transfer.amountMinor,
            transactedAt: Iso.fromDateTime(transfer.transactedAt),
            note: Value(transfer.note),
          ),
        );
    return true;
  }
}
