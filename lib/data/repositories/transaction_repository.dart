import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
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

/// Confirmed debit spend for one local calendar day, for the Reports
/// calendar heatmap.
class DailySpend extends Equatable {
  const DailySpend({required this.date, required this.spentMinor});

  /// Local midnight of the day this total covers.
  final DateTime date;
  final int spentMinor;

  @override
  List<Object?> get props => [date, spentMinor];
}

/// Confirmed debit spend for one month, for the Reports trend chart.
class MonthSpend extends Equatable {
  const MonthSpend({required this.period, required this.spentMinor});

  /// Month key, `YYYY-MM`.
  final String period;
  final int spentMinor;

  @override
  List<Object?> get props => [period, spentMinor];
}

/// An account's spend within one period, for the Reports account
/// breakdown.
class AccountSpend extends Equatable {
  const AccountSpend({
    required this.accountId,
    required this.accountName,
    required this.spentMinor,
  });

  final String accountId;
  final String accountName;
  final int spentMinor;

  @override
  List<Object?> get props => [accountId, accountName, spentMinor];
}

class TransactionRepository {
  TransactionRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  /// Decodes a stored row into the model the rest of the app uses —
  /// ISO strings become [DateTime], status/direction/source codes
  /// become enums, and the metadata blob is parsed once here instead of
  /// by every screen that touches a transaction.
  static Transaction _fromRow(TransactionRow row) => Transaction(
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
  );

  Future<Transaction?> byId(String id) async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<Transaction?> byIdempotencyKey(String key) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.userId.equals(userId) & t.idempotencyKey.equals(key))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Fuzzy duplicate candidates: same amount + direction, transacted
  /// within [window] of [transactedAt] (plan §10.2). Merchant similarity
  /// is checked by the caller (DedupeService).
  Future<List<Transaction>> fuzzyCandidates({
    required int amountMinor,
    required TxDirection direction,
    required DateTime transactedAt,
    Duration window = const Duration(minutes: 30),
  }) async {
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
    return (await query.get()).map(_fromRow).toList();
  }

  /// Inserts a draft as a transaction row. The caller has already run
  /// dedupe and decided [status]/[duplicateOfId].
  Future<Transaction> insertDraft(
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
            receiptPath: Value(draft.receiptPath),
          ),
        );
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    return _fromRow(row);
  }

  Stream<List<Transaction>> watchRecent({int limit = 100}) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Every transaction, unbounded — for CSV export and backups, where
  /// truncating at a display-friendly limit would silently drop rows.
  Future<List<Transaction>> getAllForExport() async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Re-inserts a transaction from a backup, preserving its original id
  /// so importing the same backup twice does not duplicate anything.
  /// Returns false without writing if a transaction with this id
  /// already exists, or if `idempotencyKey` collides with a different
  /// row (its unique constraint) — the caller decides whether either
  /// counts as a real failure.
  Future<bool> restoreTransaction(Transaction tx) async {
    final existing = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(tx.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    try {
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: tx.id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              accountId: tx.accountId,
              categoryId: Value(tx.categoryId),
              amountMinor: tx.amountMinor,
              currency: Value(tx.currency),
              direction: tx.direction.name,
              merchant: Value(tx.merchant),
              description: Value(tx.description),
              transactedAt: Iso.fromDateTime(tx.transactedAt),
              source: tx.source.name,
              confidence: Value(tx.confidence),
              status: tx.status.dbName,
              rawCaptureId: Value(tx.rawCaptureId),
              idempotencyKey: tx.idempotencyKey,
              duplicateOfId: Value(tx.duplicateOfId),
              paymentMethod: Value(tx.paymentMethod),
              externalRef: Value(tx.externalRef),
              metadataJson: Value(
                tx.metadata.isEmpty ? null : jsonEncode(tx.metadata),
              ),
              receiptPath: Value(tx.receiptPath),
            ),
          );
      return true;
    } on Exception {
      return false;
    }
  }

  /// Recent transactions matching every non-null filter — a merchant or
  /// description substring, a category, an account, and/or a date
  /// range. Each filter is independent: pass only the ones the user
  /// has actually set.
  Stream<List<Transaction>> watchFiltered({
    String? query,
    String? categoryId,
    String? accountId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) {
    final t = _db.transactions;
    var predicate = t.userId.equals(userId) & t.deletedAt.isNull();

    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      final pattern = '%${trimmedQuery.toLowerCase()}%';
      predicate =
          predicate &
          (t.merchant.lower().like(pattern) |
              t.description.lower().like(pattern));
    }
    if (categoryId != null) {
      predicate = predicate & t.categoryId.equals(categoryId);
    }
    if (accountId != null) {
      predicate = predicate & t.accountId.equals(accountId);
    }
    if (from != null) {
      predicate =
          predicate &
          t.transactedAt.isBiggerOrEqualValue(Iso.fromDateTime(from));
    }
    if (to != null) {
      predicate =
          predicate & t.transactedAt.isSmallerThanValue(Iso.fromDateTime(to));
    }

    final selectQuery = _db.select(t)
      ..where((_) => predicate)
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)])
      ..limit(limit);
    return selectQuery.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Stream<List<Transaction>> watchByStatus(TxStatus status) {
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.status.equals(status.dbName) &
            t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
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

  /// Sets or clears the receipt photo path. A dedicated method rather
  /// than another optional [updateFields] argument, since "clear it"
  /// and "leave it alone" both need to be expressible and a bare
  /// nullable parameter can't distinguish them.
  Future<void> setReceiptPath(String id, String? receiptPath) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        receiptPath: Value(receiptPath),
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

  /// Confirmed debit total across every category for a month, for
  /// tracking spend against a declared income rather than a per-category
  /// limit.
  Future<int> totalSpent(String period) async {
    final (from, to) = Iso.monthBoundsUtc(period);
    final t = _db.transactions;
    final total = t.amountMinor.sum();
    final query = _db.selectOnly(t)
      ..addColumns([total])
      ..where(
        t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.direction.equals(TxDirection.debit.name) &
            t.status.equals(TxStatus.confirmed.dbName) &
            t.transactedAt.isBiggerOrEqualValue(from) &
            t.transactedAt.isSmallerThanValue(to),
      );
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  /// Confirmed debit spend per local calendar day within a month, for
  /// the Reports calendar heatmap. Bucketing happens in Dart rather
  /// than SQL because `transactedAt` is stored in UTC — grouping by a
  /// raw date substring would occasionally put a transaction on the
  /// wrong side of midnight for the user's actual timezone.
  Stream<List<DailySpend>> watchDailySpend(String period) {
    final (from, to) = Iso.monthBoundsUtc(period);
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.direction.equals(TxDirection.debit.name) &
            t.status.equals(TxStatus.confirmed.dbName) &
            t.transactedAt.isBiggerOrEqualValue(from) &
            t.transactedAt.isSmallerThanValue(to),
      );
    return query.watch().map((rows) {
      final byDay = <DateTime, int>{};
      for (final row in rows) {
        final local = Iso.toDateTime(row.transactedAt).toLocal();
        final day = DateTime(local.year, local.month, local.day);
        byDay[day] = (byDay[day] ?? 0) + row.amountMinor;
      }
      return byDay.entries
          .map((entry) => DailySpend(date: entry.key, spentMinor: entry.value))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  /// Confirmed transactions on one local calendar day, for the
  /// calendar heatmap's day drill-down. The SQL bound is widened by a
  /// day on each side to safely cover any timezone offset, then
  /// narrowed to the exact local day here.
  Future<List<Transaction>> transactionsOnDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sqlFrom = Iso.fromDateTime(start.subtract(const Duration(days: 1)));
    final sqlTo = Iso.fromDateTime(end.add(const Duration(days: 1)));

    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.transactedAt.isBiggerOrEqualValue(sqlFrom) &
            t.transactedAt.isSmallerThanValue(sqlTo),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.transactedAt)]);

    final rows = await query.get();
    return rows.map(_fromRow).where((tx) {
      final local = tx.transactedAt.toLocal();
      return !local.isBefore(start) && local.isBefore(end);
    }).toList();
  }

  /// Confirmed debit total for each of the [months] ending with
  /// [endPeriod], oldest first, for the Reports trend chart. A Future
  /// rather than a Stream — same pattern as `countBySource` — since a
  /// trend chart is fine recomputing on each Reports load or month
  /// shift rather than staying live to the millisecond.
  Future<List<MonthSpend>> spendTrend(
    String endPeriod, {
    int months = 6,
  }) async {
    final periods = [endPeriod];
    for (var i = 1; i < months; i++) {
      periods.add(Iso.previousMonthKey(periods.last));
    }

    final result = <MonthSpend>[];
    for (final period in periods.reversed) {
      result.add(
        MonthSpend(period: period, spentMinor: await totalSpent(period)),
      );
    }
    return result;
  }

  /// Confirmed debit spend per account for a month, for the Reports
  /// account breakdown.
  Stream<List<AccountSpend>> watchSpendByAccount(String period) {
    final (from, to) = Iso.monthBoundsUtc(period);
    final t = _db.transactions;
    final a = _db.accounts;
    final total = t.amountMinor.sum();
    final query = _db.selectOnly(t)
      ..addColumns([t.accountId, a.name, total])
      ..join([innerJoin(a, a.id.equalsExp(t.accountId))])
      ..where(
        t.userId.equals(userId) &
            t.deletedAt.isNull() &
            t.direction.equals(TxDirection.debit.name) &
            t.status.equals(TxStatus.confirmed.dbName) &
            t.transactedAt.isBiggerOrEqualValue(from) &
            t.transactedAt.isSmallerThanValue(to),
      )
      ..groupBy([t.accountId])
      ..orderBy([OrderingTerm.desc(total)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => AccountSpend(
              accountId: row.read(t.accountId)!,
              accountName: row.read(a.name) ?? 'Unknown',
              spentMinor: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
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
