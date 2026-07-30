import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/custom_sender.dart';

/// User-added SMS sender IDs, for banks or wallets whose alerts arrive
/// from a shortcode the built-in parsers don't already recognize.
class CustomSenderRepository {
  CustomSenderRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static CustomSender _fromRow(CustomSenderRow row) => CustomSender(
    id: row.id,
    providerKey: row.providerKey,
    senderId: row.senderId,
  );

  Stream<List<CustomSender>> watchAll() {
    final query = _db.select(_db.customSenderIds)
      ..where((s) => s.userId.equals(userId) & s.deletedAt.isNull());
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<CustomSender>> getAll() async {
    final query = _db.select(_db.customSenderIds)
      ..where((s) => s.userId.equals(userId) & s.deletedAt.isNull());
    return (await query.get()).map(_fromRow).toList();
  }

  /// Adds a sender, or reactivates it if it was previously deleted.
  Future<CustomSender> add({
    required String providerKey,
    required String senderId,
  }) async {
    final normalized = Ids.normalizeSender(senderId);
    final existing =
        await (_db.select(_db.customSenderIds)..where(
              (s) => s.userId.equals(userId) & s.senderId.equals(normalized),
            ))
            .getSingleOrNull();
    final now = Iso.nowUtc();

    if (existing == null) {
      final id = Ids.newId();
      await _db
          .into(_db.customSenderIds)
          .insert(
            CustomSenderIdsCompanion.insert(
              id: id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              providerKey: providerKey,
              senderId: normalized,
            ),
          );
      return CustomSender(
        id: id,
        providerKey: providerKey,
        senderId: normalized,
      );
    }

    await (_db.update(
      _db.customSenderIds,
    )..where((s) => s.id.equals(existing.id))).write(
      CustomSenderIdsCompanion(
        providerKey: Value(providerKey),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
    return CustomSender(
      id: existing.id,
      providerKey: providerKey,
      senderId: normalized,
    );
  }

  Future<void> delete(String id) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.customSenderIds,
    )..where((s) => s.id.equals(id))).write(
      CustomSenderIdsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
