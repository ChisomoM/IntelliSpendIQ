import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';

/// Learned merchant → category mappings, keyed by normalized merchant
/// (see `DedupeService.normalizeMerchant`). Purely an internal lookup
/// table for `MerchantCategorizer` — nothing in the UI reads this
/// directly, so there is no domain model for it.
class MerchantCategoryRuleRepository {
  MerchantCategoryRuleRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  Future<String?> categoryIdFor(String normalizedMerchant) async {
    if (normalizedMerchant.isEmpty) return null;
    final query = _db.select(_db.merchantCategoryRules)
      ..where(
        (r) =>
            r.userId.equals(userId) &
            r.normalizedMerchant.equals(normalizedMerchant) &
            r.deletedAt.isNull(),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.categoryId;
  }

  /// Records (or updates) which category a merchant should map to —
  /// called whenever the user recategorizes a transaction, so the next
  /// capture from the same merchant is categorized automatically.
  Future<void> upsert({
    required String normalizedMerchant,
    required String categoryId,
  }) async {
    if (normalizedMerchant.isEmpty) return;
    final now = Iso.nowUtc();
    final existing =
        await (_db.select(_db.merchantCategoryRules)..where(
              (r) =>
                  r.userId.equals(userId) &
                  r.normalizedMerchant.equals(normalizedMerchant),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.merchantCategoryRules)
          .insert(
            MerchantCategoryRulesCompanion.insert(
              id: Ids.newId(),
              userId: userId,
              createdAt: now,
              updatedAt: now,
              normalizedMerchant: normalizedMerchant,
              categoryId: categoryId,
            ),
          );
      return;
    }

    await (_db.update(
      _db.merchantCategoryRules,
    )..where((r) => r.id.equals(existing.id))).write(
      MerchantCategoryRulesCompanion(
        categoryId: Value(categoryId),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }
}
