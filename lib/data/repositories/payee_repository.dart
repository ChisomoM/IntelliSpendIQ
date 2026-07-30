import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/payee.dart';

class PayeeRepository {
  PayeeRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static Payee _fromRow(PayeeRow row) => Payee(id: row.id, name: row.name);

  Stream<List<Payee>> watchAll() {
    final query = _db.select(_db.payees)
      ..where((p) => p.userId.equals(userId) & p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<Payee>> getAll() async {
    final query = _db.select(_db.payees)
      ..where((p) => p.userId.equals(userId) & p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Finds an existing payee by name (case-insensitive), or creates
  /// one — the same "type a new one in" gesture as picking from the
  /// list, so the caller never has to check first.
  Future<Payee> findOrCreate(String name) async {
    final trimmed = name.trim();
    final query = _db.select(_db.payees)
      ..where(
        (p) =>
            p.userId.equals(userId) &
            p.name.lower().equals(trimmed.toLowerCase()) &
            p.deletedAt.isNull(),
      )
      ..limit(1);
    final existing = await query.getSingleOrNull();
    if (existing != null) return _fromRow(existing);

    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.payees)
        .insert(
          PayeesCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: trimmed,
          ),
        );
    return Payee(id: id, name: trimmed);
  }

  Future<void> delete(String id) async {
    final now = Iso.nowUtc();
    await (_db.update(_db.payees)..where((p) => p.id.equals(id))).write(
      PayeesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Re-inserts a payee from a backup, preserving its original id.
  /// Returns false without writing if this id already exists, or a
  /// payee with the same name (case-insensitive) is already there.
  Future<bool> restorePayee(Payee payee) async {
    final existing = await (_db.select(
      _db.payees,
    )..where((p) => p.id.equals(payee.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    try {
      await _db
          .into(_db.payees)
          .insert(
            PayeesCompanion.insert(
              id: payee.id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              name: payee.name,
            ),
          );
      return true;
    } on Exception {
      return false;
    }
  }
}
