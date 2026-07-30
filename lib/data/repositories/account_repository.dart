import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/stanchart_parser.dart';

class AccountRepository {
  AccountRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static Account _fromRow(AccountRow row) => Account(
    id: row.id,
    name: row.name,
    type: AccountType.fromDbName(row.type),
    currency: row.currency,
    isDefault: row.isDefault,
    providerKey: row.providerKey,
    balanceMinor: row.balanceMinor,
  );

  /// Day-one seed (D07): one default mobile-money account mapped to
  /// Airtel Money.
  Future<void> ensureDefaultAccount() async {
    final existing = await (_db.select(
      _db.accounts,
    )..where((a) => a.userId.equals(userId))).get();
    if (existing.isNotEmpty) return;
    final now = Iso.nowUtc();
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: Ids.newId(),
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: 'Airtel Money',
            type: AccountType.mobileMoney.dbName,
            isDefault: const Value(true),
            providerKey: const Value(AirtelMoneyParser.providerKey),
          ),
        );
  }

  Stream<List<Account>> watchAll() {
    final query = _db.select(_db.accounts)
      ..where((a) => a.userId.equals(userId) & a.deletedAt.isNull());
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<Account>> getAll() async {
    final query = _db.select(_db.accounts)
      ..where((a) => a.userId.equals(userId) & a.deletedAt.isNull());
    return (await query.get()).map(_fromRow).toList();
  }

  Future<Account> getDefault() async {
    final query = _db.select(_db.accounts)
      ..where(
        (a) =>
            a.userId.equals(userId) &
            a.isDefault.equals(true) &
            a.deletedAt.isNull(),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row != null) return _fromRow(row);
    final any = await getAll();
    return any.first;
  }

  /// Maps a parser provider to its account, creating it on first use —
  /// e.g. the StanChart account appears when the first StanChart SMS is
  /// parsed (plan §19).
  Future<Account> findOrCreateForProvider(String providerKey) async {
    final query = _db.select(_db.accounts)
      ..where(
        (a) =>
            a.userId.equals(userId) &
            a.providerKey.equals(providerKey) &
            a.deletedAt.isNull(),
      )
      ..limit(1);
    final existing = await query.getSingleOrNull();
    if (existing != null) return _fromRow(existing);

    final (name, type) = switch (providerKey) {
      AirtelMoneyParser.providerKey => (
        'Airtel Money',
        AccountType.mobileMoney,
      ),
      StanChartParser.providerKey => ('Standard Chartered', AccountType.bank),
      _ => (providerKey, AccountType.bank),
    };
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: name,
            type: type.dbName,
            providerKey: Value(providerKey),
          ),
        );
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    return _fromRow(row);
  }

  /// Updates the informational cached balance reported by provider SMS.
  Future<void> updateBalance(String accountId, int balanceMinor) async {
    await (_db.update(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        balanceMinor: Value(balanceMinor),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  /// Sets [id] as the default account, unsetting any other. A no-op
  /// if [id] doesn't exist.
  Future<void> setDefault(String id) async {
    final target = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (target == null) return;

    final now = Iso.nowUtc();
    await _db.transaction(() async {
      await (_db.update(_db.accounts)..where(
            (a) => a.userId.equals(userId) & a.isDefault.equals(true),
          ))
          .write(
            AccountsCompanion(
              isDefault: const Value(false),
              updatedAt: Value(now),
            ),
          );
      await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(isDefault: const Value(true), updatedAt: Value(now)),
      );
    });
  }

  /// Adds a user-created account, e.g. a cash wallet or a second bank
  /// account not tied to any SMS parser.
  Future<Account> create({
    required String name,
    required AccountType type,
    String? providerKey,
  }) async {
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: name,
            type: type.dbName,
            providerKey: Value(providerKey),
          ),
        );
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    return _fromRow(row);
  }

  /// Removes an account the user added by mistake or no longer uses.
  /// Existing transactions keep their account id — this only hides the
  /// account from pickers, same as every other soft delete in the app.
  /// If the deleted account was the default, another remaining account
  /// is promoted so [getDefault] always has somewhere to fall back to.
  Future<void> delete(String id) async {
    final target = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (target == null) return;

    final now = Iso.nowUtc();
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );

    if (!target.isDefault) return;
    final remaining = await getAll();
    if (remaining.isEmpty) return;
    await (_db.update(
      _db.accounts,
    )..where((a) => a.id.equals(remaining.first.id))).write(
      AccountsCompanion(isDefault: const Value(true), updatedAt: Value(now)),
    );
  }

  /// Re-inserts an account from a backup, preserving its original id
  /// so importing the same backup twice does not duplicate anything.
  /// A day-one seed gets a fresh id on every install, so an id-only
  /// check would let the seeded account collide by id yet still
  /// duplicate by provider the moment it's restored onto a device
  /// that already seeded its own — matching by `providerKey` closes
  /// that gap for provider-linked accounts.
  Future<bool> restoreAccount(Account account) async {
    final existing = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(account.id))).getSingleOrNull();
    if (existing != null) return false;
    if (account.providerKey != null) {
      final sameProvider =
          await (_db.select(_db.accounts)..where(
                (a) =>
                    a.userId.equals(userId) &
                    a.providerKey.equals(account.providerKey!) &
                    a.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (sameProvider != null) return false;
    }

    final now = Iso.nowUtc();
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: account.id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: account.name,
            type: account.type.dbName,
            currency: Value(account.currency),
            isDefault: Value(account.isDefault),
            providerKey: Value(account.providerKey),
            balanceMinor: Value(account.balanceMinor),
          ),
        );
    return true;
  }
}
