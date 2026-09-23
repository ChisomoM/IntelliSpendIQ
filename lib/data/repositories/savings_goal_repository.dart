import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';
import 'package:intellispendiq/domain/models/savings_goal_entry.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// Savings goals, modeled as earmarks on money that stays in the user's
/// real accounts — never as accounts of their own. See [SavingsGoal] and
/// [SavingsGoalEntry] for why: a contribution reserves part of a real
/// account's balance rather than moving currency into a fictitious one,
/// so "how much is saved" is always a sum over [SavingsGoalEntries]
/// rather than a mutable counter that could drift out of sync.
class SavingsGoalRepository {
  SavingsGoalRepository(
    this._db, {
    required this.userId,
    required TransactionRepository transactions,
    required BudgetPeriodRepository budgetPeriods,
  }) : _transactions = transactions,
       _budgetPeriods = budgetPeriods;

  final AppDatabase _db;
  final String userId;
  final TransactionRepository _transactions;
  final BudgetPeriodRepository _budgetPeriods;

  static SavingsGoal _fromRow(SavingsGoalRow row) => SavingsGoal(
    id: row.id,
    name: row.name,
    targetMinor: row.targetMinor,
    targetDate: row.targetDate == null ? null : Iso.toDateTime(row.targetDate!),
    defaultAccountId: row.defaultAccountId,
    status: GoalStatus.fromDbName(row.status),
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

  /// Every real account's money currently earmarked across all of the
  /// user's active goals — what a future "available to spend" figure on
  /// the Accounts screen would subtract from the computed balance.
  Stream<Map<String, int>> watchCommittedByAccount() {
    return _db
        .customSelect(
          _committedByAccountSql,
          variables: [Variable.withString(userId)],
          readsFrom: {_db.savingsGoalEntries},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<String>('account_id'): row.read<int>('committed'),
          },
        );
  }

  static const _committedByAccountSql = '''
SELECT account_id,
  COALESCE(SUM(CASE WHEN kind = 'contribution' THEN amount_minor ELSE -amount_minor END), 0) AS committed
FROM savings_goal_entries
WHERE user_id = ? AND deleted_at IS NULL
GROUP BY account_id
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
    return SavingsGoal(
      id: id,
      name: name,
      targetMinor: targetMinor,
      targetDate: targetDate,
      defaultAccountId: defaultAccountId,
      status: GoalStatus.active,
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

  /// Earmarks [amountMinor] of [accountId]'s balance toward [goalId].
  /// Moves no real money — see the class doc comment.
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
    await _insertEntry(
      goalId: goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      kind: GoalEntryKind.contribution,
      transactedAt: transactedAt,
      note: note,
    );
  }

  /// Releases [amountMinor] back to [accountId]'s available balance
  /// without spending it — the user changed their mind about this much
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
    await _insertEntry(
      goalId: goalId,
      accountId: accountId,
      amountMinor: amountMinor,
      kind: GoalEntryKind.withdrawal,
      transactedAt: transactedAt,
      note: note,
    );
  }

  /// Converts (some of) a goal into an actual purchase: records a real
  /// expense [Transaction] for [amountMinor] — the full price paid,
  /// which may exceed what was saved — and withdraws whatever portion
  /// of that was actually saved toward the goal, tagging the withdrawal
  /// with the transaction it funded. The saved portion never shows up
  /// as spend twice: it was never spend in the first place until now.
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

    final periodId = (await _budgetPeriods.ensurePeriodContaining(
      transactedAt,
    )).id;
    final tx = await _transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
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

    if (fundedByGoal > 0) {
      await _insertEntry(
        goalId: goalId,
        accountId: accountId,
        amountMinor: fundedByGoal,
        kind: GoalEntryKind.withdrawal,
        transactedAt: transactedAt,
        note: merchant == null ? 'Spent' : 'Spent on $merchant',
        linkedTransactionId: tx.id,
      );
    }
    return tx;
  }

  /// Returns every account's still-earmarked money for [goalId] back to
  /// that same account, then soft-deletes the goal. Money always goes
  /// back to the account it was earmarked *from* — never lumped into a
  /// single default account — so each account's own availability is
  /// restored correctly even when a goal was funded from several.
  Future<void> delete(String id) async {
    final byAccount = await _netByAccount(id);
    final now = Iso.nowUtc();
    for (final entry in byAccount.entries) {
      if (entry.value <= 0) continue;
      await _insertEntry(
        goalId: id,
        accountId: entry.key,
        amountMinor: entry.value,
        kind: GoalEntryKind.withdrawal,
        transactedAt: DateTime.now(),
        note: 'Goal deleted — returned to account',
      );
    }
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
      SavingsGoalsCompanion(
        status: Value(GoalStatus.abandoned.dbName),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
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
