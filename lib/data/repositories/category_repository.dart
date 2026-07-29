import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/category.dart';

class CategoryRepository {
  CategoryRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static Category _fromRow(CategoryRow row) => Category(
    id: row.id,
    name: row.name,
    icon: row.icon,
    color: row.color,
    parentId: row.parentId,
    isSystem: row.isSystem,
    sortOrder: row.sortOrder,
  );

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

  Stream<List<Category>> watchAll() {
    final query = _db.select(_db.categories)
      ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<Category>> getAll() async {
    final query = _db.select(_db.categories)
      ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return (await query.get()).map(_fromRow).toList();
  }

  Future<Category?> byName(String name) async {
    final query = _db.select(_db.categories)
      ..where(
        (c) =>
            c.userId.equals(userId) &
            c.name.lower().equals(name.toLowerCase()) &
            c.deletedAt.isNull(),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<Category> create(String name, {String? icon}) async {
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
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
    return _fromRow(row);
  }
}
