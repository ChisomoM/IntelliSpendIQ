import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/category_icon_key.dart';
import 'package:intellispendiq/domain/models/enums.dart';

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
    type: CategoryType.fromDbName(row.categoryType),
    budgetedAmountMinor: row.budgetedAmountMinor,
  );

  /// Default system categories seeded on first launch (plan §6.2).
  /// "Income" is the only seed on the income side — everything else
  /// is an expense category.
  static const seedNames = [
    ('Food', CategoryIconKey.food, CategoryType.expense),
    ('Transport', CategoryIconKey.transport, CategoryType.expense),
    ('Airtime/Data', CategoryIconKey.mobile, CategoryType.expense),
    ('Transfers', CategoryIconKey.transfer, CategoryType.expense),
    ('Shopping', CategoryIconKey.shopping, CategoryType.expense),
    ('Bills', CategoryIconKey.bills, CategoryType.expense),
    ('Income', CategoryIconKey.income, CategoryType.income),
    ('Fees/Charges', CategoryIconKey.bank, CategoryType.expense),
    ('Uncategorized', CategoryIconKey.other, CategoryType.expense),
    ('Other', CategoryIconKey.other, CategoryType.expense),
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
            categoryType: Value(seed.$3.dbName),
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

  Future<Category> create(
    String name, {
    String? icon,
    String? parentId,
    CategoryType type = CategoryType.expense,
    int? budgetedAmountMinor,
  }) async {
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
            parentId: Value(parentId),
            sortOrder: const Value(1000),
            categoryType: Value(type.dbName),
            budgetedAmountMinor: Value(budgetedAmountMinor),
          ),
        );
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
    return _fromRow(row);
  }

  /// Renames a category, changes its icon, moves it under a parent (or
  /// out from under one), or sets its standing budget. Allowed for
  /// system categories too — only deletion is restricted for those.
  /// Pass [clearIcon]/[clearParent]/[clearBudget] to remove that field
  /// rather than leaving it untouched.
  Future<void> update(
    String id, {
    String? name,
    String? icon,
    bool clearIcon = false,
    String? parentId,
    bool clearParent = false,
    CategoryType? type,
    int? budgetedAmountMinor,
    bool clearBudget = false,
  }) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        icon: clearIcon
            ? const Value(null)
            : (icon == null ? const Value.absent() : Value(icon)),
        parentId: clearParent
            ? const Value(null)
            : (parentId == null ? const Value.absent() : Value(parentId)),
        categoryType: type == null ? const Value.absent() : Value(type.dbName),
        budgetedAmountMinor: clearBudget
            ? const Value(null)
            : (budgetedAmountMinor == null
                  ? const Value.absent()
                  : Value(budgetedAmountMinor)),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  /// Moves budgeted amount from one category to another — both must
  /// exist and [fromCategoryId] must have at least [amountMinor]
  /// budgeted. Returns false without writing anything otherwise.
  Future<bool> transferBudget({
    required String fromCategoryId,
    required String toCategoryId,
    required int amountMinor,
  }) async {
    if (amountMinor <= 0) return false;
    final from = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(fromCategoryId))).getSingleOrNull();
    final to = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(toCategoryId))).getSingleOrNull();
    if (from == null || to == null) return false;
    final fromBudget = from.budgetedAmountMinor ?? 0;
    if (fromBudget < amountMinor) return false;

    final now = Iso.nowUtc();
    await _db.transaction(() async {
      await (_db.update(
        _db.categories,
      )..where((c) => c.id.equals(fromCategoryId))).write(
        CategoriesCompanion(
          budgetedAmountMinor: Value(fromBudget - amountMinor),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(
        _db.categories,
      )..where((c) => c.id.equals(toCategoryId))).write(
        CategoriesCompanion(
          budgetedAmountMinor: Value(
            (to.budgetedAmountMinor ?? 0) + amountMinor,
          ),
          updatedAt: Value(now),
        ),
      );
    });
    return true;
  }

  /// Removes a user-created category. Refuses system categories (the
  /// day-one seeds) — those stay put so the taxonomy the rest of the
  /// app assumes always exists. Returns false without writing anything
  /// if [id] is a system category or doesn't exist.
  Future<bool> delete(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null || row.isSystem) return false;

    final now = Iso.nowUtc();
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    return true;
  }

  /// Re-inserts a category from a backup, preserving its original id
  /// so importing the same backup twice does not duplicate anything.
  ///
  /// A day-one seed gets a fresh id on every install, so an id-only
  /// check would let a system category collide by id yet still
  /// duplicate by name the moment it's restored onto a device that
  /// already ran its own seeding — matching by name for system
  /// categories specifically closes that gap.
  Future<bool> restoreCategory(Category category) async {
    final existing = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(category.id))).getSingleOrNull();
    if (existing != null) return false;
    if (category.isSystem && await byName(category.name) != null) {
      return false;
    }

    final now = Iso.nowUtc();
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: category.id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: category.name,
            icon: Value(category.icon),
            color: Value(category.color),
            parentId: Value(category.parentId),
            isSystem: Value(category.isSystem),
            sortOrder: Value(category.sortOrder),
            categoryType: Value(category.type.dbName),
            budgetedAmountMinor: Value(category.budgetedAmountMinor),
          ),
        );
    return true;
  }
}
