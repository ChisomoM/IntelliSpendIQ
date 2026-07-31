import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/budget_schedule.dart';
import 'package:intellispendiq/domain/models/category_budget.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/services/budget_period_generator.dart';

/// Persists budget schedules, period instances, overall plans, and
/// per-period category envelopes.
class BudgetPeriodRepository {
  BudgetPeriodRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

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
  );

  static CategoryBudget _categoryBudgetFromRow(CategoryBudgetRow row) =>
      CategoryBudget(
        id: row.id,
        periodId: row.periodId,
        categoryId: row.categoryId,
        amountMinor: row.amountMinor,
      );

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
  Future<BudgetPeriod> ensurePeriodContaining(DateTime reference) async {
    final schedule = await ensureSchedule();
    final bounds = BudgetPeriodGenerator.boundsContaining(schedule, reference);
    return _ensurePeriod(schedule, bounds);
  }

  /// Moves [delta] periods from [current] (-1 previous, +1 next).
  Future<BudgetPeriod> shiftPeriod(BudgetPeriod current, int delta) async {
    final schedule = await ensureSchedule();
    final startLocal = Iso.toDateTime(current.startAt).toLocal();
    final endLocal = Iso.toDateTime(current.endAt).toLocal();
    final bounds = BudgetPeriodGenerator.shift(
      schedule,
      DateTime(startLocal.year, startLocal.month, startLocal.day),
      DateTime(endLocal.year, endLocal.month, endLocal.day),
      delta,
    );
    return _ensurePeriod(schedule, bounds);
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

  /// Copies overall + category plans from the previous period when this
  /// one is empty and the previous opted into carry-over. Also seeds
  /// category envelopes from standing category templates when neither
  /// period has rows yet.
  Future<void> carryForwardInto(BudgetPeriod period) async {
    final previous = await _previousPeriod(period);
    final now = Iso.nowUtc();

    if (period.overallAmountMinor == null &&
        previous != null &&
        previous.carryOver &&
        previous.overallAmountMinor != null) {
      await (_db.update(
        _db.budgetPeriods,
      )..where((p) => p.id.equals(period.id))).write(
        BudgetPeriodsCompanion(
          overallAmountMinor: Value(previous.overallAmountMinor),
          updatedAt: Value(now),
        ),
      );
    }

    final existingCategoryBudgets = await categoryBudgetsFor(period.id);
    if (existingCategoryBudgets.isNotEmpty) return;

    if (previous != null && previous.carryOver) {
      final prevBudgets = await categoryBudgetsFor(previous.id);
      if (prevBudgets.isNotEmpty) {
        await _db.batch((batch) {
          for (final budget in prevBudgets) {
            batch.insert(
              _db.categoryBudgets,
              CategoryBudgetsCompanion.insert(
                id: Ids.newId(),
                userId: userId,
                createdAt: now,
                updatedAt: now,
                periodId: period.id,
                categoryId: budget.categoryId,
                amountMinor: budget.amountMinor,
              ),
            );
          }
        });
        return;
      }
    }

    await _seedFromStandingTemplates(period.id);
  }

  Future<void> _seedFromStandingTemplates(String periodId) async {
    final categories =
        await (_db.select(_db.categories)..where(
              (c) =>
                  c.userId.equals(userId) &
                  c.deletedAt.isNull() &
                  c.budgetedAmountMinor.isNotNull(),
            ))
            .get();
    if (categories.isEmpty) return;
    final now = Iso.nowUtc();
    await _db.batch((batch) {
      for (final category in categories) {
        final amount = category.budgetedAmountMinor;
        if (amount == null) continue;
        batch.insert(
          _db.categoryBudgets,
          CategoryBudgetsCompanion.insert(
            id: Ids.newId(),
            userId: userId,
            createdAt: now,
            updatedAt: now,
            periodId: periodId,
            categoryId: category.id,
            amountMinor: amount,
          ),
        );
      }
    });
  }

  Future<BudgetPeriod?> _previousPeriod(BudgetPeriod period) async {
    final schedule = await ensureSchedule();
    final startLocal = Iso.toDateTime(period.startAt).toLocal();
    final endLocal = Iso.toDateTime(period.endAt).toLocal();
    final bounds = BudgetPeriodGenerator.shift(
      schedule,
      DateTime(startLocal.year, startLocal.month, startLocal.day),
      DateTime(endLocal.year, endLocal.month, endLocal.day),
      -1,
    );
    final startUtc = Iso.fromDateTime(bounds.start);
    final endUtc = Iso.fromDateTime(bounds.endExclusive);
    final row =
        await (_db.select(_db.budgetPeriods)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.startAt.equals(startUtc) &
                  p.endAt.equals(endUtc) &
                  p.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _periodFromRow(row);
  }

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

    // Keep standing template in sync so Categories editor / new periods
    // inherit the latest figure.
    await (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(categoryId))).write(
      CategoriesCompanion(
        budgetedAmountMinor: Value(amountMinor),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft-deletes the period envelope and clears the standing template.
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
    await (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(categoryId))).write(
      CategoriesCompanion(
        budgetedAmountMinor: const Value(null),
        updatedAt: Value(now),
      ),
    );
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
