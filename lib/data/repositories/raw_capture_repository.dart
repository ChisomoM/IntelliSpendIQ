import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';

class RawCaptureRepository {
  RawCaptureRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  Future<RawCaptureRow?> byId(String id) {
    return (_db.select(
      _db.rawCaptures,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  Future<RawCaptureRow?> byContentHash(String hash) {
    final query = _db.select(_db.rawCaptures)
      ..where((r) => r.userId.equals(userId) & r.contentHash.equals(hash))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<RawCaptureRow?> byAndroidSmsId(String androidSmsId) {
    final query = _db.select(_db.rawCaptures)
      ..where(
        (r) => r.userId.equals(userId) & r.androidSmsId.equals(androidSmsId),
      )
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Persists a capture immediately — before any parsing — so a
  /// financial event is never lost even if everything downstream fails
  /// (D23).
  Future<RawCaptureRow> insert(
    CaptureInput input, {
    required String contentHash,
  }) async {
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.rawCaptures)
        .insert(
          RawCapturesCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            sourceChannel: input.channel.dbName,
            sender: Value(input.sender),
            body: input.body,
            receivedAt: Iso.fromDateTime(input.receivedAt),
            androidSmsId: Value(input.androidSmsId),
            packageName: Value(input.packageName),
            contentHash: contentHash,
          ),
        );
    return (_db.select(
      _db.rawCaptures,
    )..where((r) => r.id.equals(id))).getSingle();
  }

  Future<void> markParsed(
    String id, {
    required String parserKey,
    required String transactionId,
  }) => _update(
    id,
    parseStatus: ParseStatus.parsed,
    parserKey: parserKey,
    parsedTransactionId: transactionId,
  );

  Future<void> markFailed(String id, {String? parserKey, String? error}) =>
      _update(
        id,
        parseStatus: ParseStatus.failed,
        parserKey: parserKey,
        error: error,
      );

  Future<void> markIgnored(String id, {String? error}) =>
      _update(id, parseStatus: ParseStatus.ignored, error: error);

  Future<void> _update(
    String id, {
    required ParseStatus parseStatus,
    String? parserKey,
    String? parsedTransactionId,
    String? error,
  }) async {
    await (_db.update(_db.rawCaptures)..where((r) => r.id.equals(id))).write(
      RawCapturesCompanion(
        parseStatus: Value(parseStatus.name),
        parserKey: parserKey == null ? const Value.absent() : Value(parserKey),
        parsedTransactionId: parsedTransactionId == null
            ? const Value.absent()
            : Value(parsedTransactionId),
        error: error == null ? const Value.absent() : Value(error),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  /// Failed captures for the Review Inbox.
  Stream<List<RawCaptureRow>> watchFailed() {
    final query = _db.select(_db.rawCaptures)
      ..where(
        (r) =>
            r.userId.equals(userId) &
            r.parseStatus.equals(ParseStatus.failed.name) &
            r.deletedAt.isNull(),
      )
      ..orderBy([(r) => OrderingTerm.desc(r.receivedAt)]);
    return query.watch();
  }

  Stream<int> watchFailedCount() {
    final count = countAll();
    final query = _db.selectOnly(_db.rawCaptures)
      ..addColumns([count])
      ..where(
        _db.rawCaptures.userId.equals(userId) &
            _db.rawCaptures.deletedAt.isNull() &
            _db.rawCaptures.parseStatus.equals(ParseStatus.failed.name),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Capture health: counts by parse status (plan Phase 1f metric).
  Future<Map<String, int>> countByParseStatus() async {
    final r = _db.rawCaptures;
    final count = countAll();
    final query = _db.selectOnly(r)
      ..addColumns([r.parseStatus, count])
      ..where(r.userId.equals(userId) & r.deletedAt.isNull())
      ..groupBy([r.parseStatus]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(r.parseStatus) ?? 'unknown': row.read(count) ?? 0,
    };
  }

  /// Marks a failed capture resolved after the human created/edited the
  /// transaction from the inbox.
  Future<void> resolveManually(String id, {String? transactionId}) => _update(
    id,
    parseStatus: ParseStatus.parsed,
    parsedTransactionId: transactionId,
    error: 'resolved_manually',
  );
}
