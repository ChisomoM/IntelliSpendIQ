import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';
import 'package:intellispendiq/domain/models/savings_goal_entry.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// Savings goals, each backed by its own hidden [Account] (see
/// [SavingsGoal.accountId] / [Account.linkedGoalId]). A contribution is a
/// real [Transfer] out of the chosen account and into that hidden one —
/// money actually leaves the account's balance, rather than merely being
/// earmarked on paper — and spending draws the purchase back out of
/// whichever account(s) actually hold it. [SavingsGoalEntries] stays as
/// the goal's own ledger (contributions minus withdrawals), so "how much
/// is saved" is always a sum over entries rather than a mutable counter
/// that could drift out of sync — it's just backed by real money
/// movements now instead of bookkeeping-only ones.
class SavingsGoalRepository {
  SavingsGoalRepository(
    this._db, {
    required this.userId,
    required TransactionRepository transactions,
    required TransferRepository transfers,
    required AccountRepository accounts,
    required BudgetPeriodRepository budgetPeriods,
  }) : _transactions = transactions,
       _transfers = transfers,
       _accounts = accounts,
       _budgetPeriods = budgetPeriods;

  final AppDatabase _db;
  final String userId;
  final TransactionRepository _transactions;
  final TransferRepository _transfers;
  final AccountRepository _accounts;
  final BudgetPeriodRepository _budgetPeriods;

  static SavingsGoal _fromRow(SavingsGoalRow row) => SavingsGoal(
    id: row.id,
    name: row.name,
    targetMinor: row.targetMinor,
    targetDate: row.targetDate == null ? null : Iso.toDateTime(row.targetDate!),
    defaultAccountId: row.defaultAccountId,
    status: GoalStatus.fromDbName(row.status),
    accountId: row.accountId,
  );

  static SavingsGoalEntry _entryFromRow(SavingsGoalEntryRow row) =>
      SavingsGoalEntry(
        id: row.id,
        goalId: row.goalId,
        accountId: row.accountId,
        amountMinor: row.amountMinor,
        kind: GoalEntryKind.fromDbName(row.kind),
        transactedAt: Iso.toDateTime(row.transactedAt),
        note: row.note,
        linkedTransactionId: row.linkedTransactionId,
        linkedTransferId: row.linkedTransferId,
      );

  Stream<List<SavingsGoal>> watchAll() {
    final query = _db.select(_db.savingsGoals)
      ..where((g) => g.userId.equals(userId) & g.deletedAt.isNull())
      ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Every goal's live saved total: contributions minus withdrawals,
  /// summed straight from [SavingsGoalEntries] — the same computed
  /// approach `AccountRepository.watchComputedBalances` uses, so a
  /// goal's progress can never drift from the entries that back it.
  Stream<Map<String, int>> watchSaved() {
    return _db
        .customSelect(
          _savedByGoalSql,
          variables: [Variable.withString(userId)],
          readsFrom: {_db.savingsGoalEntries},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<String>('goal_id'): row.read<int>('saved'),
          },
        );
  }

  static const _savedByGoalSql = '''
SELECT goal_id,
  COALESCE(SUM(CASE WHEN kind = 'contribution' THEN amount_minor ELSE -amount_minor END), 0) AS saved
FROM savings_goal_entries
WHERE user_id = ? AND deleted_at IS NULL
GROUP BY goal_id
''';

  Stream<List<SavingsGoalEntry>> watchEntries(String goalId) {
    final query = _db.select(_db.savingsGoalEntries)
      ..where(
        (e) =>
            e.userId.equals(userId) &
            e.goalId.equals(goalId) &
            e.deletedAt.isNull(),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.transactedAt)]);
    return query.watch().map((rows) => rows.map(_entryFromRow).toList());
  }

  Future<SavingsGoal> create({
    required String name,
    required int targetMinor,
    DateTime? targetDate,
    String? defaultAccountId,
  }) async {
    if (targetMinor <= 0) {
      throw ArgumentError('Target amount must be positive');
    }
    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: name,
            targetMinor: targetMinor,
            targetDate: Value(
              targetDate == null ? null : Iso.fromDateTime(targetDate),
            ),
            defaultAccountId: Value(defaultAccountId),
          ),
        );
    final account = await _accounts.createGoalAccount(id, name);
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
      SavingsGoalsCompanion(
        accountId: Value(account.id),
        updatedAt: Value(now),
      ),
    );
    return SavingsGoal(
      id: id,
      name: name,
      targetMinor: targetMinor,
      targetDate: targetDate,
      defaultAccountId: defaultAccountId,
      status: GoalStatus.active,
      accountId: account.id,
    );
  }

  Future<void> updateFields(
    String id, {
    String? name,
    int? targetMinor,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? defaultAccountId,
    bool clearDefaultAccount = false,
  }) async {
    if (targetMinor != null && targetMinor <= 0) {
      throw ArgumentError('Target amount must be positive');
    }
    final now = Iso.nowUtc();
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
      SavingsGoalsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        targetMinor: targetMinor == null
            ? const Value.absent()
            : Value(targetMinor),
        targetDate: clearTargetDate
            ? const Value(null)
            : (targetDate == null
                  ? const Value.absent()
                  : Value(Iso.fromDateTime(targetDate))),
        defaultAccountId: clearDefaultAccount
            ? const Value(null)
            : (defaultAccountId == null
                  ? const Value.absent()
                  : Value(defaultAccountId)),
        updatedAt: Value(now),
      ),
    );
  }

  /// Really transfers [amountMinor] out of [accountId] and into [goalId]'s
  /// own hidden account.
  Future<void> contribute({
    required String goalId,
    required String accountId,
    required int amountMinor,
    required DateTime transactedAt,
    String? note,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Contribution amount must be positive');
    }
    final goalAccountId = await _ensureGoalAccountId(goalId);
    final transfer = await _transfers.create(
      fromAccountId: accountId,
      toAccountId: goalAccountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      note: note,
    );
    await _insertEntry(
      goalId: goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      kind: GoalEntryKind.contribution,
      transactedAt: transactedAt,
      note: note,
      linkedTransferId: transfer.id,
    );
  }

  /// Really transfers [amountMinor] back out of [goalId]'s hidden account
  /// and into [accountId] — the user changed their mind about this much
  /// of what they'd set aside. Refuses to release more than is saved.
  Future<void> withdraw({
    required String goalId,
    required String accountId,
    required int amountMinor,
    required DateTime transactedAt,
    String? note,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Withdrawal amount must be positive');
    }
    final saved = await _savedFor(goalId);
    if (amountMinor > saved) {
      throw ArgumentError('Cannot withdraw more than is saved toward this goal');
    }
    final goalAccountId = await _ensureGoalAccountId(goalId);
    final transfer = await _transfers.create(
      fromAccountId: goalAccountId,
      toAccountId: accountId,
      amountMinor: amountMinor,
      transactedAt: transactedAt,
      note: note,
    );
    await _insertEntry(
      goalId: goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      kind: GoalEntryKind.withdrawal,
      transactedAt: transactedAt,
      note: note,
      linkedTransferId: transfer.id,
    );
  }

  /// Converts (some of) a goal into an actual purchase, for the full
  /// price paid ([amountMinor]), which may exceed what was saved. The
  /// portion already saved is real money already sitting in the goal's
  /// hidden account, so that portion is recorded as an expense against
  /// *that* account; any shortfall above what was saved is a separate
  /// expense leg against [accountId], the real account covering the
  /// difference. Returns the shortfall leg when there is one (the
  /// transaction against the user's own account), otherwise the
  /// goal-account leg — either way the single transaction a caller
  /// should point a purchase record at.
  Future<Transaction> spend({
    required String goalId,
    required String accountId,
    required int amountMinor,
    required DateTime transactedAt,
    String? categoryId,
    String? merchant,
    String? description,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be positive');
    }
    final saved = await _savedFor(goalId);
    final fundedByGoal = amountMinor < saved ? amountMinor : saved;
    final shortfall = amountMinor - fundedByGoal;
    final periodId = (await _budgetPeriods.ensurePeriodContaining(
      transactedAt,
    )).id;

    Transaction? goalTx;
    if (fundedByGoal > 0) {
      final goalAccountId = await _ensureGoalAccountId(goalId);
      goalTx = await _transactions.insertDraft(
        TransactionDraft(
          amountMinor: fundedByGoal,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: transactedAt,
          merchant: merchant,
          description: description,
          categoryId: categoryId,
          metadata: {'linkedGoalId': goalId},
        ),
        accountId: goalAccountId,
        idempotencyKey: 'goal:$goalId:spend:${Ids.newId()}',
        status: TxStatus.confirmed,
        periodId: periodId,
      );
      await _insertEntry(
        goalId: goalId,
        accountId: goalAccountId,
        amountMinor: fundedByGoal,
        kind: GoalEntryKind.withdrawal,
        transactedAt: transactedAt,
        note: merchant == null ? 'Spent' : 'Spent on $merchant',
        linkedTransactionId: goalTx.id,
      );
    }

    if (shortfall <= 0) {
      return goalTx!;
    }

    return _transactions.insertDraft(
      TransactionDraft(
        amountMinor: shortfall,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: transactedAt,
        merchant: merchant,
        description: description,
        categoryId: categoryId,
        metadata: {'linkedGoalId': goalId},
      ),
      accountId: accountId,
      idempotencyKey: 'goal:$goalId:spend:${Ids.newId()}',
      status: TxStatus.confirmed,
      periodId: periodId,
    );
  }

  /// Transfers every account's still-saved money for [goalId] back to
  /// the account it was contributed *from*, then soft-deletes the goal
  /// and its hidden account. Money always goes back to the account it
  /// came from — never lumped into a single default account — so each
  /// account's own balance is restored correctly even when a goal was
  /// funded from several.
  Future<void> delete(String id) async {
    final goalRow = await (_db.select(
      _db.savingsGoals,
    )..where((g) => g.id.equals(id))).getSingleOrNull();
    final goalAccountId = goalRow?.accountId;
    final byAccount = await _netByAccount(id);
    final now = Iso.nowUtc();
    final nowDt = DateTime.now();
    for (final entry in byAccount.entries) {
      if (entry.value <= 0 || goalAccountId == null) continue;
      final transfer = await _transfers.create(
        fromAccountId: goalAccountId,
        toAccountId: entry.key,
        amountMinor: entry.value,
        transactedAt: nowDt,
        note: 'Goal deleted — returned to account',
      );
      await _insertEntry(
        goalId: id,
        accountId: entry.key,
        amountMinor: entry.value,
        kind: GoalEntryKind.withdrawal,
        transactedAt: nowDt,
        note: 'Goal deleted — returned to account',
        linkedTransferId: transfer.id,
      );
    }
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
      SavingsGoalsCompanion(
        status: Value(GoalStatus.abandoned.dbName),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    if (goalAccountId != null) {
      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(goalAccountId))).write(
        AccountsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    }
  }

  /// The hidden account backing [goalId]'s real balance, creating one
  /// lazily if this goal predates [accountId] existing.
  Future<String> _ensureGoalAccountId(String goalId) async {
    final row = await (_db.select(
      _db.savingsGoals,
    )..where((g) => g.id.equals(goalId))).getSingle();
    if (row.accountId != null) return row.accountId!;
    final account = await _accounts.createGoalAccount(goalId, row.name);
    await (_db.update(
      _db.savingsGoals,
    )..where((g) => g.id.equals(goalId))).write(
      SavingsGoalsCompanion(
        accountId: Value(account.id),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
    return account.id;
  }

  Future<int> _savedFor(String goalId) async {
    final byAccount = await _netByAccount(goalId);
    return byAccount.values.fold<int>(0, (sum, v) => sum + v);
  }

  /// Net (contributions − withdrawals) per source account for [goalId].
  Future<Map<String, int>> _netByAccount(String goalId) async {
    final rows =
        await (_db.select(_db.savingsGoalEntries)..where(
              (e) =>
                  e.userId.equals(userId) &
                  e.goalId.equals(goalId) &
                  e.deletedAt.isNull(),
            ))
            .get();
    final byAccount = <String, int>{};
    for (final row in rows) {
      final signed = row.kind == GoalEntryKind.contribution.dbName
          ? row.amountMinor
          : -row.amountMinor;
      byAccount.update(
        row.accountId,
        (value) => value + signed,
        ifAbsent: () => signed,
      );
    }
    return byAccount;
  }

  /// Every entry for every goal, unbounded — for backups. Includes
  /// entries whose goal has since been deleted (e.g. the return-money
  /// entries [delete] writes), so a restore reproduces the source's
  /// saved totals exactly rather than only its still-active goals.
  Future<List<SavingsGoalEntry>> getAllEntriesForExport() async {
    final query = _db.select(_db.savingsGoalEntries)
      ..where((e) => e.userId.equals(userId) & e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.asc(e.transactedAt)]);
    return (await query.get()).map(_entryFromRow).toList();
  }

  /// Every goal, unbounded and including deleted ones — for backups, so
  /// a restore can still resolve the `goalId` on an entry whose goal
  /// was since removed on the source.
  Future<List<SavingsGoal>> getAllForExport() async {
    final query = _db.select(_db.savingsGoals)
      ..where((g) => g.userId.equals(userId))
      ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Re-inserts a goal from a backup, preserving its original id so
  /// importing the same backup twice does not duplicate anything.
  Future<bool> restoreGoal(SavingsGoal goal) async {
    final existing = await (_db.select(
      _db.savingsGoals,
    )..where((g) => g.id.equals(goal.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    await _db
        .into(_db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            id: goal.id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            name: goal.name,
            targetMinor: goal.targetMinor,
            targetDate: Value(
              goal.targetDate == null ? null : Iso.fromDateTime(goal.targetDate!),
            ),
            defaultAccountId: Value(goal.defaultAccountId),
            status: Value(goal.status.dbName),
            accountId: Value(goal.accountId),
          ),
        );
    return true;
  }

  /// Re-inserts a contribution/withdrawal entry from a backup,
  /// preserving its original id. Restore always writes goals before
  /// entries (see `BackupService`), so the entry's `goalId` already
  /// resolves by the time this runs.
  Future<bool> restoreEntry(SavingsGoalEntry entry) async {
    final existing = await (_db.select(
      _db.savingsGoalEntries,
    )..where((e) => e.id.equals(entry.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    await _db
        .into(_db.savingsGoalEntries)
        .insert(
          SavingsGoalEntriesCompanion.insert(
            id: entry.id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            goalId: entry.goalId,
            accountId: entry.accountId,
            amountMinor: entry.amountMinor,
            kind: entry.kind.dbName,
            transactedAt: Iso.fromDateTime(entry.transactedAt),
            note: Value(entry.note),
            linkedTransactionId: Value(entry.linkedTransactionId),
            linkedTransferId: Value(entry.linkedTransferId),
          ),
        );
    return true;
  }

  Future<void> _insertEntry({
    required String goalId,
    required String accountId,
    required int amountMinor,
    required GoalEntryKind kind,
    required DateTime transactedAt,
    String? note,
    String? linkedTransactionId,
    String? linkedTransferId,
  }) async {
    final now = Iso.nowUtc();
    await _db
        .into(_db.savingsGoalEntries)
        .insert(
          SavingsGoalEntriesCompanion.insert(
            id: Ids.newId(),
            userId: userId,
            createdAt: now,
            updatedAt: now,
            goalId: goalId,
            accountId: accountId,
            amountMinor: amountMinor,
            kind: kind.dbName,
            transactedAt: Iso.fromDateTime(transactedAt),
            note: Value(note),
            linkedTransactionId: Value(linkedTransactionId),
            linkedTransferId: Value(linkedTransferId),
          ),
        );
  }
}

/// Reads a transaction's `linkedGoalId` metadata, if any — set by
/// [SavingsGoalRepository.spend] so a ledger row can show it was part of
/// a savings goal without the rest of the app needing a new column.
extension SavingsGoalLink on Transaction {
  String? get linkedGoalId {
    final value = metadata['linkedGoalId'];
    return value is String ? value : null;
  }
}
