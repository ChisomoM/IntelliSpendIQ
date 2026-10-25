import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/budget_schedule.dart';
import 'package:intellispendiq/domain/models/category_budget.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/budget_period_generator.dart';

/// A cycle's income totals: [actualMinor] counts only paid envelopes,
/// [provisionalMinor] adds unpaid ones on top. [actualMinor] is the
/// figure used everywhere else — [provisionalMinor] is expectation-only.
class IncomeTotals {
  const IncomeTotals({required this.actualMinor, required this.provisionalMinor});

  final int actualMinor;
  final int provisionalMinor;
}

/// Why a cycle's dates couldn't be changed, worded for the user.
class CycleEditException implements Exception {
  const CycleEditException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a boundary move changes: the two cycles' new labels and how many
/// transactions switch cycle.
class CycleMovePreview {
  const CycleMovePreview({
    required this.earlierLabel,
    required this.laterLabel,
    required this.transactionsMoving,
    required this.movesIntoLater,
  });

  final String earlierLabel;
  final String laterLabel;
  final int transactionsMoving;

  /// True when the boundary moved earlier, so transactions pass from the
  /// earlier cycle into the later one; false for the other way round.
  final bool movesIntoLater;
}

class _MovePlan {
  const _MovePlan({
    required this.newBoundaryUtc,
    required this.earlierLabel,
    required this.laterLabel,
    required this.movesIntoLater,
    required this.movingFilter,
  });

  final String newBoundaryUtc;
  final String earlierLabel;
  final String laterLabel;
  final bool movesIntoLater;
  final Expression<bool> Function($TransactionsTable t) movingFilter;
}

/// Persists budget schedules, period instances, overall plans, and
/// per-period category envelopes.
class BudgetPeriodRepository {
  BudgetPeriodRepository(
    this._db, {
    required this.userId,
    required TransactionRepository transactions,
  }) : _transactions = transactions;

  final AppDatabase _db;
  final String userId;
  final TransactionRepository _transactions;

  static BudgetSchedule _scheduleFromRow(BudgetScheduleRow row) =>
      BudgetSchedule(
        id: row.id,
        cadence: BudgetCadence.fromDbName(row.cadence),
        anchorDay: row.anchorDay,
        anchorDate: row.anchorDate,
        startWeekday: row.startWeekday,
      );

  static BudgetPeriod _periodFromRow(BudgetPeriodRow row) => BudgetPeriod(
    id: row.id,
    scheduleId: row.scheduleId,
    startAt: row.startAt,
    endAt: row.endAt,
    label: row.label,
    overallAmountMinor: row.overallAmountMinor,
    carryOver: row.carryOver,
    budgetSource: BudgetSource.fromDbName(row.budgetSource),
  );

  static CategoryBudget _categoryBudgetFromRow(CategoryBudgetRow row) =>
      CategoryBudget(
        id: row.id,
        periodId: row.periodId,
        categoryId: row.categoryId,
        amountMinor: row.amountMinor,
        status: row.status == null
            ? null
            : IncomeStatus.fromDbName(row.status!),
        transactionId: row.transactionId,
      );

  Future<CategoryType> _categoryTypeOf(String categoryId) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingle();
    return CategoryType.fromDbName(row.categoryType);
  }

  /// Active schedule, creating a calendar-month default if missing.
  Future<BudgetSchedule> ensureSchedule() async {
    final existing = await (_db.select(
      _db.budgetSchedules,
    )..where((s) => s.userId.equals(userId) & s.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) return _scheduleFromRow(existing);

    final now = Iso.nowUtc();
    final id = Ids.newId();
    await _db
        .into(_db.budgetSchedules)
        .insert(
          BudgetSchedulesCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            cadence: BudgetCadence.calendarMonth.dbName,
          ),
        );
    return BudgetSchedule(id: id, cadence: BudgetCadence.calendarMonth);
  }

  Future<BudgetSchedule?> getSchedule() async {
    final row = await (_db.select(
      _db.budgetSchedules,
    )..where((s) => s.userId.equals(userId) & s.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _scheduleFromRow(row);
  }

  /// Updates cadence / anchors. Does not rewrite existing periods.
  Future<BudgetSchedule> updateSchedule({
    required BudgetCadence cadence,
    int? anchorDay,
    String? anchorDate,
    int? startWeekday,
    bool clearAnchorDay = false,
    bool clearAnchorDate = false,
    bool clearStartWeekday = false,
  }) async {
    final schedule = await ensureSchedule();
    final now = Iso.nowUtc();
    await (_db.update(
      _db.budgetSchedules,
    )..where((s) => s.id.equals(schedule.id))).write(
      BudgetSchedulesCompanion(
        cadence: Value(cadence.dbName),
        anchorDay: clearAnchorDay
            ? const Value(null)
            : (anchorDay == null ? const Value.absent() : Value(anchorDay)),
        anchorDate: clearAnchorDate
            ? const Value(null)
            : (anchorDate == null ? const Value.absent() : Value(anchorDate)),
        startWeekday: clearStartWeekday
            ? const Value(null)
            : (startWeekday == null
                  ? const Value.absent()
                  : Value(startWeekday)),
        updatedAt: Value(now),
      ),
    );
    return (await getSchedule())!;
  }

  /// Period containing [reference] (local), creating + seeding if needed.
  ///
  /// A saved period wins over the schedule's rule, so a cycle whose dates
  /// were adjusted (see [moveBoundary]) keeps them. The rule only fills
  /// days no saved period covers.
  Future<BudgetPeriod> ensurePeriodContaining(DateTime reference) async {
    final schedule = await ensureSchedule();
    final resolved = await _resolve(schedule, reference);
    final stored = resolved.stored;
    if (stored != null) {
      final period = _periodFromRow(stored);
      await carryForwardInto(period);
      return period;
    }
    return _ensurePeriod(schedule, resolved.bounds);
  }

  /// Moves [delta] periods from [current] (-1 previous, +1 next).
  Future<BudgetPeriod> shiftPeriod(BudgetPeriod current, int delta) async {
    final start = _localDay(current.startAt);
    final end = _localDay(current.endAt);
    final probe = switch (delta) {
      0 => start,
      > 0 => end,
      _ => DateTime(start.year, start.month, start.day - 1),
    };
    return ensurePeriodContaining(probe);
  }

  /// Every cycle from the one containing [now] back to the one
  /// containing [earliest], newest first. Computed rather than read from
  /// storage, because a cycle only gets a row once someone opens it;
  /// nothing is created here. Saved cycles keep their adjusted dates.
  /// Capped at [maxCycles].
  Future<List<LocalPeriodBounds>> cyclesBetween({
    required DateTime earliest,
    required DateTime now,
    int maxCycles = 120,
  }) async {
    final schedule = await ensureSchedule();
    var bounds = (await _resolve(schedule, now)).bounds;
    final cycles = <LocalPeriodBounds>[bounds];
    while (bounds.start.isAfter(earliest) && cycles.length < maxCycles) {
      final before = DateTime(
        bounds.start.year,
        bounds.start.month,
        bounds.start.day - 1,
      );
      bounds = (await _resolve(schedule, before)).bounds;
      cycles.add(bounds);
    }
    return cycles;
  }

  static DateTime _localDay(String iso) {
    final local = Iso.toDateTime(iso).toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// The bounds for the cycle holding [reference], and the saved period
  /// that has them, if any. Writes nothing.
  ///
  /// Saved periods are looked at first. When several overlap the day (a
  /// leftover from changing the rule, which never rewrites old periods)
  /// the one that matches the rule exactly wins, as it always has,
  /// otherwise the latest. With none saved, the rule's bounds are used
  /// but trimmed so they never overlap a saved neighbour.
  Future<({LocalPeriodBounds bounds, BudgetPeriodRow? stored})> _resolve(
    BudgetSchedule schedule,
    DateTime reference,
  ) async {
    final day = DateTime(reference.year, reference.month, reference.day);
    final dayUtc = Iso.fromDateTime(day);
    final rule = BudgetPeriodGenerator.boundsContaining(schedule, day);

    final containing =
        await (_db.select(_db.budgetPeriods)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.deletedAt.isNull() &
                  p.startAt.isSmallerOrEqualValue(dayUtc) &
                  p.endAt.isBiggerThanValue(dayUtc),
            ))
            .get();
    if (containing.isNotEmpty) {
      final ruleStart = Iso.fromDateTime(rule.start);
      final ruleEnd = Iso.fromDateTime(rule.endExclusive);
      final exact = containing
          .where((p) => p.startAt == ruleStart && p.endAt == ruleEnd)
          .firstOrNull;
      final stored =
          exact ??
          (containing..sort((a, b) => b.startAt.compareTo(a.startAt))).first;
      return (
        bounds: (
          start: _localDay(stored.startAt),
          endExclusive: _localDay(stored.endAt),
        ),
        stored: stored,
      );
    }

    final previous =
        await (_db.select(_db.budgetPeriods)
              ..where(
                (p) =>
                    p.userId.equals(userId) &
                    p.deletedAt.isNull() &
                    p.endAt.isSmallerOrEqualValue(dayUtc),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.endAt)])
              ..limit(1))
            .getSingleOrNull();
    final next =
        await (_db.select(_db.budgetPeriods)
              ..where(
                (p) =>
                    p.userId.equals(userId) &
                    p.deletedAt.isNull() &
                    p.startAt.isBiggerThanValue(dayUtc),
              )
              ..orderBy([(p) => OrderingTerm.asc(p.startAt)])
              ..limit(1))
            .getSingleOrNull();
    var start = rule.start;
    var end = rule.endExclusive;
    if (previous != null) {
      final previousEnd = _localDay(previous.endAt);
      if (previousEnd.isAfter(start)) start = previousEnd;
    }
    if (next != null) {
      final nextStart = _localDay(next.startAt);
      if (nextStart.isBefore(end)) end = nextStart;
    }
    return (bounds: (start: start, endExclusive: end), stored: null);
  }

  /// What moving the boundary between two neighbouring cycles to
  /// [newBoundary] would do, without doing it. Throws
  /// [CycleEditException] if it can't be done.
  Future<CycleMovePreview> previewBoundaryMove({
    required String earlierId,
    required String laterId,
    required DateTime newBoundary,
  }) async {
    final plan = await _planMove(earlierId, laterId, newBoundary);
    final moving = await (_db.select(_db.transactions)
          ..where((t) => plan.movingFilter(t) & t.deletedAt.isNull()))
        .get();
    return CycleMovePreview(
      earlierLabel: plan.earlierLabel,
      laterLabel: plan.laterLabel,
      transactionsMoving: moving.length,
      movesIntoLater: plan.movesIntoLater,
    );
  }

  /// Moves the boundary between two neighbouring cycles, so one ends and
  /// the other starts on [newBoundary]. Cycles stay back to back with no
  /// gap or overlap, each keeps at least one day, and the transactions
  /// that now fall on the other side of the boundary move with it. Budgets
  /// already set stay with the cycle they were set on.
  ///
  /// Starting the next cycle early (payday came before the 25th) moves
  /// the boundary earlier; a late payday moves it later.
  Future<CycleMovePreview> moveBoundary({
    required String earlierId,
    required String laterId,
    required DateTime newBoundary,
  }) async {
    final plan = await _planMove(earlierId, laterId, newBoundary);
    final preview = await previewBoundaryMove(
      earlierId: earlierId,
      laterId: laterId,
      newBoundary: newBoundary,
    );
    final now = Iso.nowUtc();
    await _db.transaction(() async {
      await (_db.update(_db.budgetPeriods)
            ..where((p) => p.id.equals(earlierId)))
          .write(
            BudgetPeriodsCompanion(
              endAt: Value(plan.newBoundaryUtc),
              label: Value(plan.earlierLabel),
              updatedAt: Value(now),
            ),
          );
      await (_db.update(_db.budgetPeriods)..where((p) => p.id.equals(laterId)))
          .write(
            BudgetPeriodsCompanion(
              startAt: Value(plan.newBoundaryUtc),
              label: Value(plan.laterLabel),
              updatedAt: Value(now),
            ),
          );
      await (_db.update(_db.transactions)
            ..where((t) => plan.movingFilter(t)))
          .write(
            TransactionsCompanion(
              periodId: Value(plan.movesIntoLater ? laterId : earlierId),
              updatedAt: Value(now),
            ),
          );
    });
    return preview;
  }

  Future<_MovePlan> _planMove(
    String earlierId,
    String laterId,
    DateTime newBoundary,
  ) async {
    final earlier = await getPeriod(earlierId);
    final later = await getPeriod(laterId);
    if (earlier == null || later == null) {
      throw const CycleEditException('That cycle no longer exists.');
    }
    if (earlier.endAt != later.startAt) {
      throw const CycleEditException(
        'These two cycles are not next to each other.',
      );
    }
    final day = DateTime(newBoundary.year, newBoundary.month, newBoundary.day);
    final earlierStart = _localDay(earlier.startAt);
    final laterEnd = _localDay(later.endAt);
    if (!day.isAfter(earlierStart) || !day.isBefore(laterEnd)) {
      throw const CycleEditException(
        'That date has to leave each cycle at least one day.',
      );
    }
    final newUtc = Iso.fromDateTime(day);
    final oldUtc = earlier.endAt;
    if (newUtc == oldUtc) {
      throw const CycleEditException('The cycles already change on that date.');
    }
    final movesIntoLater = newUtc.compareTo(oldUtc) < 0;
    // Only the slice between the old and new boundary changes hands.
    final sliceStart = movesIntoLater ? newUtc : oldUtc;
    final sliceEnd = movesIntoLater ? oldUtc : newUtc;
    final fromId = movesIntoLater ? earlierId : laterId;
    return _MovePlan(
      newBoundaryUtc: newUtc,
      earlierLabel: Iso.periodLabel(earlierStart, day),
      laterLabel: Iso.periodLabel(day, laterEnd),
      movesIntoLater: movesIntoLater,
      movingFilter: (t) =>
          t.userId.equals(userId) &
          t.periodId.equals(fromId) &
          t.transactedAt.isBiggerOrEqualValue(sliceStart) &
          t.transactedAt.isSmallerThanValue(sliceEnd),
    );
  }

  Future<BudgetPeriod?> getPeriod(String id) async {
    final row = await (_db.select(
      _db.budgetPeriods,
    )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _periodFromRow(row);
  }

  Stream<BudgetPeriod?> watchPeriod(String id) {
    final query = _db.select(_db.budgetPeriods)
      ..where((p) => p.id.equals(id) & p.deletedAt.isNull());
    return query.watch().map(
      (rows) => rows.isEmpty ? null : _periodFromRow(rows.first),
    );
  }

  Future<BudgetPeriod> _ensurePeriod(
    BudgetSchedule schedule,
    LocalPeriodBounds bounds,
  ) async {
    final startUtc = Iso.fromDateTime(bounds.start);
    final endUtc = Iso.fromDateTime(bounds.endExclusive);
    final existing =
        await (_db.select(_db.budgetPeriods)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.startAt.equals(startUtc) &
                  p.endAt.equals(endUtc) &
                  p.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await carryForwardInto(_periodFromRow(existing));
      return _periodFromRow(
        (await (_db.select(
              _db.budgetPeriods,
            )..where((p) => p.id.equals(existing.id))).getSingle()),
      );
    }

    final now = Iso.nowUtc();
    final id = Ids.newId();
    final label = BudgetPeriodGenerator.labelFor(bounds);
    await _db
        .into(_db.budgetPeriods)
        .insert(
          BudgetPeriodsCompanion.insert(
            id: id,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            scheduleId: schedule.id,
            startAt: startUtc,
            endAt: endUtc,
            label: label,
          ),
        );
    final created = BudgetPeriod(
      id: id,
      scheduleId: schedule.id,
      startAt: startUtc,
      endAt: endUtc,
      label: label,
    );
    await carryForwardInto(created);
    return (await getPeriod(id))!;
  }

  /// Periods stay independent: opening a new cycle does not copy the
  /// previous overall plan or category envelopes. Budgets must be set
  /// explicitly for each period.
  Future<void> carryForwardInto(BudgetPeriod period) async {}

  /// Sets a manual overall amount. Switches [budgetSource] back to
  /// manual — call [setIncomeDerivedBudget] instead to derive it from
  /// income.
  Future<void> setOverallAmount({
    required String periodId,
    required int amountMinor,
    bool carryOver = true,
  }) async {
    await (_db.update(
      _db.budgetPeriods,
    )..where((p) => p.id.equals(periodId))).write(
      BudgetPeriodsCompanion(
        overallAmountMinor: Value(amountMinor),
        carryOver: Value(carryOver),
        budgetSource: Value(BudgetSource.manual.dbName),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  Future<void> clearOverallAmount(String periodId) async {
    await (_db.update(
      _db.budgetPeriods,
    )..where((p) => p.id.equals(periodId))).write(
      BudgetPeriodsCompanion(
        overallAmountMinor: const Value(null),
        budgetSource: Value(BudgetSource.manual.dbName),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  /// Switches this period to deriving its overall amount from income
  /// ([BudgetSource.incomeActual] or [BudgetSource.incomeProvisional])
  /// and stores the currently computed figure. Callers should also call
  /// this again whenever income for the period changes, so the stored
  /// figure stays current.
  Future<void> setIncomeDerivedBudget({
    required String periodId,
    required BudgetSource source,
  }) async {
    assert(source != BudgetSource.manual);
    final totals = await incomeTotalsForPeriod(periodId);
    final amount = source == BudgetSource.incomeActual
        ? totals.actualMinor
        : totals.provisionalMinor;
    await (_db.update(
      _db.budgetPeriods,
    )..where((p) => p.id.equals(periodId))).write(
      BudgetPeriodsCompanion(
        overallAmountMinor: Value(amount),
        budgetSource: Value(source.dbName),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  Future<List<CategoryBudget>> categoryBudgetsFor(String periodId) async {
    final rows =
        await (_db.select(_db.categoryBudgets)..where(
              (b) =>
                  b.userId.equals(userId) &
                  b.periodId.equals(periodId) &
                  b.deletedAt.isNull(),
            ))
            .get();
    return rows.map(_categoryBudgetFromRow).toList();
  }

  Stream<List<CategoryBudget>> watchCategoryBudgets(String periodId) {
    final query = _db.select(_db.categoryBudgets)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.periodId.equals(periodId) &
            b.deletedAt.isNull(),
      );
    return query.watch().map((rows) => rows.map(_categoryBudgetFromRow).toList());
  }

  Future<void> upsertCategoryBudget({
    required String periodId,
    required String categoryId,
    required int amountMinor,
  }) async {
    final existing =
        await (_db.select(_db.categoryBudgets)..where(
              (b) =>
                  b.userId.equals(userId) &
                  b.periodId.equals(periodId) &
                  b.categoryId.equals(categoryId),
            ))
            .getSingleOrNull();
    final now = Iso.nowUtc();
    if (existing == null) {
      await _db
          .into(_db.categoryBudgets)
          .insert(
            CategoryBudgetsCompanion.insert(
              id: Ids.newId(),
              userId: userId,
              createdAt: now,
              updatedAt: now,
              periodId: periodId,
              categoryId: categoryId,
              amountMinor: amountMinor,
            ),
          );
    } else {
      await (_db.update(
        _db.categoryBudgets,
      )..where((b) => b.id.equals(existing.id))).write(
        CategoryBudgetsCompanion(
          amountMinor: Value(amountMinor),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }

    // Expense categories keep a standing template so the Categories
    // editor / new periods inherit the latest limit. Income categories
    // deliberately don't: an income plan belongs to one cycle only and
    // must never carry into the next.
    if (await _categoryTypeOf(categoryId) == CategoryType.expense) {
      await (_db.update(
        _db.categories,
      )..where((c) => c.id.equals(categoryId))).write(
        CategoriesCompanion(
          budgetedAmountMinor: Value(amountMinor),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Soft-deletes the period envelope. Also clears the standing template
  /// for expense categories — income categories never had one written.
  Future<void> clearCategoryBudget({
    required String periodId,
    required String categoryId,
  }) async {
    final now = Iso.nowUtc();
    final existing =
        await (_db.select(_db.categoryBudgets)..where(
              (b) =>
                  b.userId.equals(userId) &
                  b.periodId.equals(periodId) &
                  b.categoryId.equals(categoryId) &
                  b.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.categoryBudgets,
      )..where((b) => b.id.equals(existing.id))).write(
        CategoryBudgetsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    if (await _categoryTypeOf(categoryId) == CategoryType.expense) {
      await (_db.update(
        _db.categories,
      )..where((c) => c.id.equals(categoryId))).write(
        CategoriesCompanion(
          budgetedAmountMinor: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Marks an income envelope paid, backing it with a real credit
  /// transaction (created with [amountMinor]/[transactedAt], which may
  /// differ from the envelope's planned amount).
  Future<void> markCategoryBudgetPaid({
    required String periodId,
    required String categoryId,
    required String accountId,
    required int amountMinor,
    required DateTime transactedAt,
  }) async {
    final tx = await _transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.credit,
        source: TxSource.manual,
        transactedAt: transactedAt,
        categoryId: categoryId,
      ),
      accountId: accountId,
      idempotencyKey: Ids.newId(),
      status: TxStatus.confirmed,
      periodId: periodId,
    );

    final now = Iso.nowUtc();
    final existing =
        await (_db.select(_db.categoryBudgets)..where(
              (b) =>
                  b.userId.equals(userId) &
                  b.periodId.equals(periodId) &
                  b.categoryId.equals(categoryId),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.categoryBudgets)
          .insert(
            CategoryBudgetsCompanion.insert(
              id: Ids.newId(),
              userId: userId,
              createdAt: now,
              updatedAt: now,
              periodId: periodId,
              categoryId: categoryId,
              amountMinor: amountMinor,
              status: Value(IncomeStatus.paid.dbName),
              transactionId: Value(tx.id),
            ),
          );
    } else {
      await (_db.update(
        _db.categoryBudgets,
      )..where((b) => b.id.equals(existing.id))).write(
        CategoryBudgetsCompanion(
          amountMinor: Value(amountMinor),
          status: Value(IncomeStatus.paid.dbName),
          transactionId: Value(tx.id),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Marks an income envelope unpaid again. The transaction that had
  /// backed it, if any, is left alone in the ledger — only the link is
  /// cleared.
  Future<void> markCategoryBudgetUnpaid({
    required String periodId,
    required String categoryId,
  }) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.categoryBudgets,
    )..where(
          (b) =>
              b.userId.equals(userId) &
              b.periodId.equals(periodId) &
              b.categoryId.equals(categoryId) &
              b.deletedAt.isNull(),
        ))
        .write(
          CategoryBudgetsCompanion(
            status: Value(IncomeStatus.unpaid.dbName),
            transactionId: const Value(null),
            updatedAt: Value(now),
          ),
        );
  }

  /// Actual (paid-only) and provisional (paid + unpaid) income totals
  /// for this period, summed across every income-type category envelope.
  Future<IncomeTotals> incomeTotalsForPeriod(String periodId) async {
    final budgets = await categoryBudgetsFor(periodId);
    var actual = 0;
    var provisional = 0;
    for (final budget in budgets) {
      if (await _categoryTypeOf(budget.categoryId) != CategoryType.income) {
        continue;
      }
      provisional += budget.amountMinor;
      if (budget.isPaid) actual += budget.amountMinor;
    }
    return IncomeTotals(actualMinor: actual, provisionalMinor: provisional);
  }

  Future<bool> transferCategoryBudget({
    required String periodId,
    required String fromCategoryId,
    required String toCategoryId,
    required int amountMinor,
  }) async {
    if (amountMinor <= 0) return false;
    final budgets = await categoryBudgetsFor(periodId);
    final from = budgets.where((b) => b.categoryId == fromCategoryId).firstOrNull;
    final toAmount = budgets
        .where((b) => b.categoryId == toCategoryId)
        .map((b) => b.amountMinor)
        .firstOrNull;
    if (from == null || from.amountMinor < amountMinor) return false;

    await upsertCategoryBudget(
      periodId: periodId,
      categoryId: fromCategoryId,
      amountMinor: from.amountMinor - amountMinor,
    );
    await upsertCategoryBudget(
      periodId: periodId,
      categoryId: toCategoryId,
      amountMinor: (toAmount ?? 0) + amountMinor,
    );
    return true;
  }

  Future<List<BudgetPeriod>> getAllPeriodsForExport() async {
    final rows = await (_db.select(
      _db.budgetPeriods,
    )..where((p) => p.userId.equals(userId) & p.deletedAt.isNull())).get();
    return rows.map(_periodFromRow).toList();
  }

  Future<List<CategoryBudget>> getAllCategoryBudgetsForExport() async {
    final rows = await (_db.select(
      _db.categoryBudgets,
    )..where((b) => b.userId.equals(userId) & b.deletedAt.isNull())).get();
    return rows.map(_categoryBudgetFromRow).toList();
  }
}
