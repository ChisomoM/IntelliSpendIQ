import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/label.dart';

class LabelRepository {
  LabelRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static Label _fromRow(LabelRow row) =>
      Label(id: row.id, name: row.name, color: row.color);

  Stream<List<Label>> watchAll() {
    final query = _db.select(_db.labels)
      ..where((l) => l.userId.equals(userId) & l.deletedAt.isNull())
      ..orderBy([(l) => OrderingTerm.asc(l.name)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<Label>> getAll() async {
    final query = _db.select(_db.labels)
      ..where((l) => l.userId.equals(userId) & l.deletedAt.isNull())
      ..orderBy([(l) => OrderingTerm.asc(l.name)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Finds an existing label by name (case-insensitive), or creates
  /// one.
  Future<Label> findOrCreate(String name, {String? color}) async {
    final trimmed = name.trim();
    final query = _db.select(_db.labels)
      ..where(
        (l) =>
            l.userId.equals(userId) &
            l.name.lower().equals(trimmed.toLowerCase()) &
            l.deletedAt.isNull(),
      )
      ..limit(1);
    final existing = await query.getSingleOrNull();
    if (existing != null) return _fromRow(existing);

    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.labels)
        .insert(
          LabelsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: trimmed,
            color: Value(color),
          ),
        );
    return Label(id: id, name: trimmed, color: color);
  }

  Future<void> delete(String id) async {
    final now = Iso.nowUtc();
    await (_db.update(_db.labels)..where((l) => l.id.equals(id))).write(
      LabelsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Re-inserts a label from a backup, preserving its original id.
  /// Returns false without writing if this id already exists, or a
  /// label with the same name (case-insensitive) is already there.
  Future<bool> restoreLabel(Label label) async {
    final existing = await (_db.select(
      _db.labels,
    )..where((l) => l.id.equals(label.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    try {
      await _db
          .into(_db.labels)
          .insert(
            LabelsCompanion.insert(
              id: label.id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              name: label.name,
              color: Value(label.color),
            ),
          );
      return true;
    } on Exception {
      return false;
    }
  }
}
