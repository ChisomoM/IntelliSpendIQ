import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/stanchart_parser.dart';

class AccountRepository {
  AccountRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

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

  Stream<List<AccountRow>> watchAll() {
    final query = _db.select(_db.accounts)
      ..where((a) => a.userId.equals(userId) & a.deletedAt.isNull());
    return query.watch();
  }

  Future<List<AccountRow>> getAll() {
    final query = _db.select(_db.accounts)
      ..where((a) => a.userId.equals(userId) & a.deletedAt.isNull());
    return query.get();
  }

  Future<AccountRow> getDefault() async {
    final query = _db.select(_db.accounts)
      ..where(
        (a) =>
            a.userId.equals(userId) &
            a.isDefault.equals(true) &
            a.deletedAt.isNull(),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row != null) return row;
    final any = await getAll();
    return any.first;
  }

  /// Maps a parser provider to its account, creating it on first use —
  /// e.g. the StanChart account appears when the first StanChart SMS is
  /// parsed (plan §19).
  Future<AccountRow> findOrCreateForProvider(String providerKey) async {
    final query = _db.select(_db.accounts)
      ..where(
        (a) =>
            a.userId.equals(userId) &
            a.providerKey.equals(providerKey) &
            a.deletedAt.isNull(),
      )
      ..limit(1);
    final existing = await query.getSingleOrNull();
    if (existing != null) return existing;

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
    return (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
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
}
