import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';

class CategoryRepository {
  CategoryRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  /// Default system categories seeded on first launch (plan §6.2).
  static const seedNames = [
    ('Food', '🍲'),
    ('Transport', '🚌'),
    ('Airtime/Data', '📱'),
    ('Transfers', '🔁'),
    ('Shopping', '🛍️'),
    ('Bills', '🧾'),
    ('Income', '💰'),
    ('Fees/Charges', '🏦'),
    ('Uncategorized', '❓'),
    ('Other', '📦'),
  ];

  Future<void> ensureSeeds() async {
    final existing = await (_db.select(
      _db.categories,
    )..where((c) => c.userId.equals(userId))).get();
    if (existing.isNotEmpty) return;
    final now = Iso.nowUtc();
    await _db.batch((batch) {
      for (final (index, seed) in seedNames.indexed) {
        batch.insert(
          _db.categories,
          CategoriesCompanion.insert(
            id: Ids.newId(),
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: seed.$1,
            icon: Value(seed.$2),
            isSystem: const Value(true),
            sortOrder: Value(index),
          ),
        );
      }
    });
  }

  Stream<List<CategoryRow>> watchAll() {
    final query = _db.select(_db.categories)
      ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return query.watch();
  }

  Future<List<CategoryRow>> getAll() async {
    final query = _db.select(_db.categories)
      ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return query.get();
  }

  Future<CategoryRow?> byName(String name) {
    final query = _db.select(_db.categories)
      ..where(
        (c) =>
            c.userId.equals(userId) &
            c.name.lower().equals(name.toLowerCase()) &
            c.deletedAt.isNull(),
      )
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<CategoryRow> create(String name, {String? icon}) async {
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: name,
            icon: Value(icon),
            sortOrder: const Value(1000),
          ),
        );
    return (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
  }
}
