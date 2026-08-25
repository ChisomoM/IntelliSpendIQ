import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';

/// Wipes every financial record on this device and starts over.
///
/// The day-one seeds ([CategoryRepository.ensureSeeds],
/// [AccountRepository.ensureDefaultAccount], the default budget
/// schedule/period) are recreated exactly as on first launch, and the
/// SMS backfill watermark is pinned to now so a later backfill never
/// re-ingests a historical message — only messages that arrive from
/// this point on are captured. Sender configuration (custom sender
/// ids) and app settings (PIN, biometrics, theme) are left untouched;
/// this clears data, not device configuration.
class DataResetService {
  DataResetService({
    required AppDatabase db,
    required SettingsRepository settings,
    required CategoryRepository categories,
    required AccountRepository accounts,
    required BudgetPeriodRepository budgetPeriods,
  }) : _db = db,
       _settings = settings,
       _categories = categories,
       _accounts = accounts,
       _budgetPeriods = budgetPeriods;

  final AppDatabase _db;
  final SettingsRepository _settings;
  final CategoryRepository _categories;
  final AccountRepository _accounts;
  final BudgetPeriodRepository _budgetPeriods;

  Future<void> resetAllData() async {
    await _db.transaction(() async {
      await _db.delete(_db.transactionLabels).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.transfers).go();
      await _db.delete(_db.rawCaptures).go();
      await _db.delete(_db.categoryBudgets).go();
      await _db.delete(_db.budgetPeriods).go();
      await _db.delete(_db.budgetSchedules).go();
      await _db.delete(_db.overallBudgets).go();
      await _db.delete(_db.merchantCategoryRules).go();
      await _db.delete(_db.payees).go();
      await _db.delete(_db.labels).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();
    });

    // Past this point nothing older than "now" should ever surface
    // again, even from a device whose SMS inbox still holds it.
    await _settings.set(
      SettingsRepository.smsBackfillWatermarkKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );

    await _categories.ensureSeeds();
    await _accounts.ensureDefaultAccount();
    await _budgetPeriods.ensureSchedule();
    await _budgetPeriods.ensurePeriodContaining(DateTime.now());
  }
}
