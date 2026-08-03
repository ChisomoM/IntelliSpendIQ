import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';

class TransferRepository {
  TransferRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static const _feesChargesName = 'Fees/Charges';

  static String feeIdempotencyKey(String transferId) =>
      'transfer:$transferId:fee';

  static Transfer _fromRow(TransferRow row) => Transfer(
    id: row.id,
    fromAccountId: row.fromAccountId,
    toAccountId: row.toAccountId,
    amountMinor: row.amountMinor,
    transactedAt: Iso.toDateTime(row.transactedAt),
    note: row.note,
  );

  static Transaction _txFromRow(TransactionRow row) => Transaction(
    id: row.id,
    accountId: row.accountId,
    categoryId: row.categoryId,
    amountMinor: row.amountMinor,
    currency: row.currency,
    direction: TxDirection.fromName(row.direction),
    merchant: row.merchant,
    description: row.description,
    transactedAt: Iso.toDateTime(row.transactedAt),
    source: TxSource.fromName(row.source),
    confidence: row.confidence,
    status: TxStatus.fromDbName(row.status),
    rawCaptureId: row.rawCaptureId,
    idempotencyKey: row.idempotencyKey,
    duplicateOfId: row.duplicateOfId,
    paymentMethod: row.paymentMethod,
    externalRef: row.externalRef,
    metadata: row.metadataJson == null
        ? const {}
        : jsonDecode(row.metadataJson!) as Map<String, Object?>,
    receiptPath: row.receiptPath,
    payeeId: row.payeeId,
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

  /// Live fee debit linked to [transferId], if any.
  Future<Transaction?> findFeeForTransfer(String transferId) async {
    final row = await _feeRowForTransfer(transferId);
    if (row == null || row.deletedAt != null) return null;
    return _txFromRow(row);
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
    int? feeMinor,
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
      await _syncFee(
        transferId: id,
        fromAccountId: fromTransaction.accountId,
        transactedAt: fromTransaction.transactedAt,
        feeMinor: feeMinor,
        now: now,
      );
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

  /// Records a transfer directly, without linking it from two existing
  /// transaction legs. Some moves never generate a matching pair on
  /// their own — an ATM cash withdrawal is a bank debit SMS with
  /// nothing on the other side, since a cash account has no way to
  /// send a message of its own — so this is the manual fallback for
  /// those.
  ///
  /// Optional [feeMinor] is recorded as a separate Fees/Charges debit
  /// on the from-account (same shape as SMS capture fees).
  Future<Transfer> create({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required DateTime transactedAt,
    String? note,
    int? feeMinor,
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
              fromAccountId: fromAccountId,
              toAccountId: toAccountId,
              amountMinor: amountMinor,
              transactedAt: Iso.fromDateTime(transactedAt),
              note: Value(note),
            ),
          );
      await _syncFee(
        transferId: id,
        fromAccountId: fromAccountId,
        transactedAt: transactedAt,
        feeMinor: feeMinor,
        now: now,
      );
    });
    return Transfer(
      id: id,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      note: note,
    );
  }

  /// Turns a single existing transaction into a transfer by picking the
  /// other account. Soft-deletes [source] so balances and spend totals
  /// are not double-counted — the same reason [linkTransfer] soft-deletes
  /// both legs.
  ///
  /// Direction decides which side [source] occupies: a debit left this
  /// account (from = source, to = [otherAccountId]); a credit arrived
  /// here (to = source, from = [otherAccountId]).
  Future<Transfer> convertFromTransaction({
    required Transaction source,
    required String otherAccountId,
    required int amountMinor,
    required DateTime transactedAt,
    String? note,
    int? feeMinor,
  }) async {
    if (otherAccountId == source.accountId) {
      throw ArgumentError(
        'Transfer counterparty must be a different account',
      );
    }
    if (amountMinor <= 0) {
      throw ArgumentError('Transfer amount must be positive');
    }

    final isDebit = source.direction == TxDirection.debit;
    final fromAccountId = isDebit ? source.accountId : otherAccountId;
    final toAccountId = isDebit ? otherAccountId : source.accountId;
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
              fromAccountId: fromAccountId,
              toAccountId: toAccountId,
              amountMinor: amountMinor,
              transactedAt: Iso.fromDateTime(transactedAt),
              note: Value(note),
              fromTransactionId: Value(isDebit ? source.id : null),
              toTransactionId: Value(isDebit ? null : source.id),
            ),
          );
      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(source.id))).write(
        TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _syncFee(
        transferId: id,
        fromAccountId: fromAccountId,
        transactedAt: transactedAt,
        feeMinor: feeMinor,
        now: now,
      );
    });

    return Transfer(
      id: id,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      note: note,
    );
  }

  /// Patches fields on an existing transfer. Omitted arguments are left
  /// alone — same [Value.absent] pattern as transaction updates.
  ///
  /// [feeMinor] / [clearFee] sync the linked Fees/Charges debit: clear
  /// removes it; a positive [feeMinor] creates or updates it.
  Future<void> updateFields(
    String id, {
    String? fromAccountId,
    String? toAccountId,
    int? amountMinor,
    DateTime? transactedAt,
    String? note,
    bool clearNote = false,
    int? feeMinor,
    bool clearFee = false,
  }) async {
    if (fromAccountId != null &&
        toAccountId != null &&
        fromAccountId == toAccountId) {
      throw ArgumentError('Transfer accounts must be different');
    }

    final now = Iso.nowUtc();
    await _db.transaction(() async {
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id))).write(
        TransfersCompanion(
          fromAccountId: fromAccountId == null
              ? const Value.absent()
              : Value(fromAccountId),
          toAccountId: toAccountId == null
              ? const Value.absent()
              : Value(toAccountId),
          amountMinor: amountMinor == null
              ? const Value.absent()
              : Value(amountMinor),
          transactedAt: transactedAt == null
              ? const Value.absent()
              : Value(Iso.fromDateTime(transactedAt)),
          note: clearNote
              ? const Value(null)
              : (note == null ? const Value.absent() : Value(note)),
          updatedAt: Value(now),
        ),
      );

      if (!clearFee && feeMinor == null && fromAccountId == null &&
          transactedAt == null) {
        return;
      }

      final row = await (_db.select(
        _db.transfers,
      )..where((t) => t.id.equals(id))).getSingle();

      if (clearFee || (feeMinor != null && feeMinor <= 0)) {
        await _softDeleteFeeRow(await _feeRowForTransfer(id), now);
        return;
      }

      if (feeMinor != null || fromAccountId != null || transactedAt != null) {
        final existingFee = await _feeRowForTransfer(id);
        // Only touch the fee when the caller set feeMinor, or when a
        // live fee needs its account/date kept in sync with the transfer.
        if (feeMinor == null &&
            (existingFee == null || existingFee.deletedAt != null)) {
          return;
        }
        await _syncFee(
          transferId: id,
          fromAccountId: row.fromAccountId,
          transactedAt: Iso.toDateTime(row.transactedAt),
          feeMinor: feeMinor ?? existingFee!.amountMinor,
          now: now,
        );
      }
    });
  }

  Future<void> softDelete(String id) async {
    final now = Iso.nowUtc();
    await _db.transaction(() async {
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id))).write(
        TransfersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _softDeleteFeeRow(await _feeRowForTransfer(id), now);
    });
  }

  /// Clears [deletedAt] so a soft-deleted transfer reappears in the feed.
  /// Also restores the linked fee debit, if any.
  Future<void> undelete(String id) async {
    final now = Iso.nowUtc();
    await _db.transaction(() async {
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id))).write(
        TransfersCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      final fee = await _feeRowForTransfer(id);
      if (fee != null && fee.deletedAt != null) {
        await (_db.update(
          _db.transactions,
        )..where((t) => t.id.equals(fee.id))).write(
          TransactionsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }
    });
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

  Future<TransactionRow?> _feeRowForTransfer(String transferId) {
    return (_db.select(_db.transactions)..where(
          (t) => t.idempotencyKey.equals(feeIdempotencyKey(transferId)),
        ))
        .getSingleOrNull();
  }

  Future<String?> _feesChargesCategoryId() async {
    final row =
        await (_db.select(_db.categories)
              ..where(
                (c) =>
                    c.userId.equals(userId) &
                    c.name.lower().equals(_feesChargesName.toLowerCase()) &
                    c.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  /// Creates, updates, or clears the sibling fee debit for a transfer.
  /// [feeMinor] null or ≤0 clears any existing fee.
  Future<void> _syncFee({
    required String transferId,
    required String fromAccountId,
    required DateTime transactedAt,
    required int? feeMinor,
    required String now,
  }) async {
    if (feeMinor == null || feeMinor <= 0) {
      await _softDeleteFeeRow(await _feeRowForTransfer(transferId), now);
      return;
    }

    final existing = await _feeRowForTransfer(transferId);
    final categoryId = await _feesChargesCategoryId();
    final metadata = jsonEncode({
      'family': 'fee',
      'transferId': transferId,
    });

    if (existing != null) {
      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(existing.id))).write(
        TransactionsCompanion(
          accountId: Value(fromAccountId),
          categoryId: categoryId == null
              ? const Value.absent()
              : Value(categoryId),
          amountMinor: Value(feeMinor),
          direction: Value(TxDirection.debit.name),
          description: const Value('Transfer fee'),
          transactedAt: Value(Iso.fromDateTime(transactedAt)),
          status: Value(TxStatus.confirmed.dbName),
          metadataJson: Value(metadata),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return;
    }

    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: Ids.newId(),
            userId: userId,
            createdAt: now,
            updatedAt: now,
            accountId: fromAccountId,
            categoryId: Value(categoryId),
            amountMinor: feeMinor,
            direction: TxDirection.debit.name,
            description: const Value('Transfer fee'),
            transactedAt: Iso.fromDateTime(transactedAt),
            source: TxSource.manual.name,
            status: TxStatus.confirmed.dbName,
            idempotencyKey: feeIdempotencyKey(transferId),
            metadataJson: Value(metadata),
          ),
        );
  }

  Future<void> _softDeleteFeeRow(TransactionRow? fee, String now) async {
    if (fee == null || fee.deletedAt != null) return;
    await (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(fee.id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
