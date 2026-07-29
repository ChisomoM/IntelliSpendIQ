import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// A category's spend within one period, for reports and budgets.
///
/// Equatable so cubit states holding these compare by value and do not
/// emit spurious rebuilds.
class CategorySpend extends Equatable {
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.spentMinor,
  });

  final String? categoryId;
  final String categoryName;
  final int spentMinor;

  @override
  List<Object?> get props => [categoryId, categoryName, spentMinor];
}

class TransactionRepository {
  TransactionRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  Future<TransactionRow?> byId(String id) {
    return (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<TransactionRow?> byIdempotencyKey(String key) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.userId.equals(userId) & t.idempotencyKey.equals(key))
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Fuzzy duplicate candidates: same amount + direction, transacted
  /// within [window] of [transactedAt] (plan §10.2). Merchant similarity
  /// is checked by the caller (DedupeService).
  Future<List<TransactionRow>> fuzzyCandidates({
    required int amountMinor,
    required TxDirection direction,
    required DateTime transactedAt,
    Duration window = const Duration(minutes: 30),
  }) {
    final from = Iso.fromDateTime(transactedAt.subtract(window));
    final to = Iso.fromDateTime(transactedAt.add(window));
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.amountMinor.equals(amountMinor) &
            t.direction.equals(direction.name) &
            t.transactedAt.isBetweenValues(from, to) &
            t.deletedAt.isNull(),
      );
    return query.get();
  }

  /// Inserts a draft as a transaction row. The caller has already run
  /// dedupe and decided [status]/[duplicateOfId].
  Future<TransactionRow> insertDraft(
    TransactionDraft draft, {
    required String accountId,
    required String idempotencyKey,
    required TxStatus status,
    String? rawCaptureId,
    String? duplicateOfId,
  }) async {
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            accountId: accountId,
            categoryId: Value(draft.categoryId),
            amountMinor: draft.amountMinor,
            currency: Value(draft.currency),
            direction: draft.direction.name,
            merchant: Value(draft.merchant),
            description: Value(draft.description),
            transactedAt: Iso.fromDateTime(draft.transactedAt),
            source: draft.source.name,
            confidence: Value(draft.confidence),
            status: status.dbName,
            rawCaptureId: Value(rawCaptureId),
            idempotencyKey: idempotencyKey,
            duplicateOfId: Value(duplicateOfId),
            paymentMethod: Value(draft.paymentMethod),
            externalRef: Value(draft.externalRef),
            metadataJson: Value(
              draft.metadata.isEmpty ? null : jsonEncode(draft.metadata),
            ),
          ),
        );
    return (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<TransactionRow>> watchRecent({int limit = 100}) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<TransactionRow>> watchByStatus(TxStatus status) {
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.status.equals(status.dbName) &
            t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)]);
    return query.watch();
  }

  /// Count of transactions needing human attention, for the inbox badge.
  Stream<int> watchReviewCount() {
    final count = countAll();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([count])
      ..where(
        _db.transactions.userId.equals(userId) &
            _db.transactions.deletedAt.isNull() &
            _db.transactions.status.isIn([
              TxStatus.needsReview.dbName,
              TxStatus.duplicateSuspect.dbName,
            ]),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> updateFields(
    String id, {
    String? categoryId,
    String? merchant,
    String? description,
    int? amountMinor,
    DateTime? transactedAt,
    TxStatus? status,
    String? duplicateOfId,
  }) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        categoryId: categoryId == null
            ? const Value.absent()
            : Value(categoryId),
        merchant: merchant == null ? const Value.absent() : Value(merchant),
        description: description == null
            ? const Value.absent()
            : Value(description),
        amountMinor: amountMinor == null
            ? const Value.absent()
            : Value(amountMinor),
        transactedAt: transactedAt == null
            ? const Value.absent()
            : Value(Iso.fromDateTime(transactedAt)),
        status: status == null ? const Value.absent() : Value(status.dbName),
        duplicateOfId: duplicateOfId == null
            ? const Value.absent()
            : Value(duplicateOfId),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  Future<void> confirm(String id) =>
      updateFields(id, status: TxStatus.confirmed);

  Future<void> softDelete(String id) async {
    final now = Iso.nowUtc();
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Confirmed debit spend per category for a month, computed locally
  /// (deterministic SQL — no LLM anywhere near the math).
  Stream<List<CategorySpend>> watchSpendByCategory(String period) {
    final (from, to) = Iso.monthBoundsUtc(period);
    final t = _db.transactions;
    final c = _db.categories;
    final total = t.amountMinor.sum();
    final query = _db.selectOnly(t)
      ..addColumns([t.categoryId, c.name, total])
      ..join([leftOuterJoin(c, c.id.equalsExp(t.categoryId))])
      ..where(
        t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.direction.equals(TxDirection.debit.name) &
            t.status.equals(TxStatus.confirmed.dbName) &
            t.transactedAt.isBiggerOrEqualValue(from) &
            t.transactedAt.isSmallerThanValue(to),
      )
      ..groupBy([t.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CategorySpend(
              categoryId: row.read(t.categoryId),
              categoryName: row.read(c.name) ?? 'Uncategorized',
              spentMinor: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Confirmed debit total for one category in a month (budget math).
  Future<int> spentForCategory(String categoryId, String period) async {
    final (from, to) = Iso.monthBoundsUtc(period);
    final t = _db.transactions;
    final total = t.amountMinor.sum();
    final query = _db.selectOnly(t)
      ..addColumns([total])
      ..where(
        t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.categoryId.equals(categoryId) &
            t.direction.equals(TxDirection.debit.name) &
            t.status.equals(TxStatus.confirmed.dbName) &
            t.transactedAt.isBiggerOrEqualValue(from) &
            t.transactedAt.isSmallerThanValue(to),
      );
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  /// Capture health metric: how many of this month's captured
  /// transactions came in per source (plan §Phase 1f).
  Future<Map<String, int>> countBySource(String period) async {
    final (from, to) = Iso.monthBoundsUtc(period);
    final t = _db.transactions;
    final count = countAll();
    final query = _db.selectOnly(t)
      ..addColumns([t.source, count])
      ..where(
        t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.transactedAt.isBiggerOrEqualValue(from) &
            t.transactedAt.isSmallerThanValue(to),
      )
      ..groupBy([t.source]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(t.source) ?? 'unknown': row.read(count) ?? 0,
    };
  }
}
