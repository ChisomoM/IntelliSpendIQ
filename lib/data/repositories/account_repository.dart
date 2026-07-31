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
    balanceAsOf: row.balanceAsOf == null
        ? null
        : Iso.toDateTime(row.balanceAsOf!),
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

  /// Sets a new balance checkpoint by hand — the anchor
  /// [watchComputedBalances] adds every later transaction/transfer on
  /// top of. Only ever called from a manual edit; SMS parsing no
  /// longer calls this (a text isn't reliable enough to treat as
  /// ground truth — messages can arrive late, out of order, or not at
  /// all).
  Future<void> updateBalance(String accountId, int balanceMinor) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        balanceMinor: Value(balanceMinor),
        balanceAsOf: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Every account's live balance: its last manual checkpoint (or the
  /// full history, if none was ever set — see [_computedBalanceSql])
  /// plus every confirmed transaction and transfer recorded against it
  /// since.
  ///
  /// A single raw query rather than composing several repository calls
  /// so it stays reactive — Drift only re-runs a watched query when a
  /// table it actually reads from changes, so [readsFrom] has to name
  /// every table this depends on for [Stream.watch] to fire on new
  /// transactions and transfers, not just account edits.
  Stream<Map<String, int>> watchComputedBalances() {
    return _db
        .customSelect(
          _computedBalanceSql,
          variables: [Variable.withString(userId)],
          readsFrom: {_db.accounts, _db.transactions, _db.transfers},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<String>('account_id'): row.read<int>(
                'computed_balance',
              ),
          },
        );
  }

  /// `balance_as_of IS NULL` (no checkpoint ever set) counts every
  /// transaction/transfer ever recorded, full stop — deliberately NOT
  /// falling back to the account row's own `created_at`. An account is
  /// often created lazily, on its first parsed SMS, long after the
  /// real-world account existed; a transaction dated before that isn't
  /// out of bounds, it's just backdated relative to when this app
  /// first heard about the account.
  static const _computedBalanceSql = '''
SELECT
  a.id AS account_id,
  COALESCE(a.balance_minor, 0)
    + COALESCE((
        SELECT SUM(CASE WHEN t.direction = 'credit' THEN t.amount_minor ELSE -t.amount_minor END)
        FROM transactions t
        WHERE t.account_id = a.id
          AND t.status = 'confirmed'
          AND t.deleted_at IS NULL
          AND (a.balance_as_of IS NULL OR t.transacted_at > a.balance_as_of)
      ), 0)
    + COALESCE((
        SELECT SUM(tr.amount_minor) FROM transfers tr
        WHERE tr.to_account_id = a.id AND tr.deleted_at IS NULL
          AND (a.balance_as_of IS NULL OR tr.transacted_at > a.balance_as_of)
      ), 0)
    - COALESCE((
        SELECT SUM(tr.amount_minor) FROM transfers tr
        WHERE tr.from_account_id = a.id AND tr.deleted_at IS NULL
          AND (a.balance_as_of IS NULL OR tr.transacted_at > a.balance_as_of)
      ), 0) AS computed_balance
FROM accounts a
WHERE a.user_id = ? AND a.deleted_at IS NULL
''';

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
            balanceAsOf: Value(
              account.balanceAsOf == null
                  ? null
                  : Iso.fromDateTime(account.balanceAsOf!),
            ),
          ),
        );
    return true;
  }
}
