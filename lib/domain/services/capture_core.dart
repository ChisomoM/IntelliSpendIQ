import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/db/connection.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/custom_sender_repository.dart';
import 'package:intellispendiq/data/repositories/fee_schedule_repository.dart';
import 'package:intellispendiq/data/repositories/merchant_category_rule_repository.dart';
import 'package:intellispendiq/data/repositories/nudge_settings_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';
import 'package:intellispendiq/domain/services/dedupe_service.dart';
import 'package:intellispendiq/domain/services/merchant_categorizer.dart';

/// Everything needed to turn one raw message into a saved transaction
/// and, if it could not be categorized, a nudge: the repositories, the
/// parser registry, the categorizer and the capture pipeline.
///
/// Deliberately free of Firebase, licensing, the AI providers and the
/// reminder plugin. `AppServices` builds on it for the running app, and
/// the background entrypoint builds on it alone, so an SMS that arrives
/// while the app is closed goes through exactly the same pipeline.
class CaptureCore {
  CaptureCore._({
    required this.db,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.rawCaptures,
    required this.budgetPeriods,
    required this.settings,
    required this.customSenders,
    required this.merchantCategoryRules,
    required this.nudgeSettings,
    required this.registry,
    required this.merchantCategorizer,
    required this.captureService,
    required this.captureNudger,
  });

  /// Wires the core around an already-open [db].
  ///
  /// [nudgeNotifier] is what posts the "what was this?" notification;
  /// without one nudging is off rather than failing on a missing
  /// platform channel (tests).
  static Future<CaptureCore> create({
    required AppDatabase db,
    required String userId,
    required FeeScheduleRepository fees,
    NudgeNotifier? nudgeNotifier,
  }) async {
    final accounts = AccountRepository(db, userId: userId);
    final categories = CategoryRepository(db, userId: userId);
    final transactions = TransactionRepository(db, userId: userId);
    final rawCaptures = RawCaptureRepository(db, userId: userId);
    final budgetPeriods = BudgetPeriodRepository(
      db,
      userId: userId,
      transactions: transactions,
    );
    final settings = SettingsRepository(db);
    final customSenders = CustomSenderRepository(db, userId: userId);
    final merchantCategoryRules = MerchantCategoryRuleRepository(
      db,
      userId: userId,
    );
    final nudgeSettings = NudgeSettingsRepository(settings);

    final registry = ParserRegistry()
      ..setCustomSenders({
        for (final sender in await customSenders.getAll())
          sender.senderId: sender.providerKey,
      });
    final merchantCategorizer = MerchantCategorizer(
      rules: merchantCategoryRules,
      categories: categories,
    );
    final captureService = CaptureService(
      registry: registry,
      rawCaptures: rawCaptures,
      transactions: transactions,
      accounts: accounts,
      categories: categories,
      budgetPeriods: budgetPeriods,
      dedupe: DedupeService(transactions),
      categorizer: merchantCategorizer,
      fees: fees,
    );
    final CaptureNudger captureNudger = nudgeNotifier == null
        ? NoopCaptureNudger()
        : BatchingCaptureNudger(
            settings: nudgeSettings,
            notifier: nudgeNotifier,
            suggestions: () => _suggestCategories(transactions, categories),
            categoryOptions: () => _categoryOptions(categories),
          );

    return CaptureCore._(
      db: db,
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      rawCaptures: rawCaptures,
      budgetPeriods: budgetPeriods,
      settings: settings,
      customSenders: customSenders,
      merchantCategoryRules: merchantCategoryRules,
      nudgeSettings: nudgeSettings,
      registry: registry,
      merchantCategorizer: merchantCategorizer,
      captureService: captureService,
      captureNudger: captureNudger,
    );
  }

  /// Opens the encrypted database from Keystore-backed storage and wires
  /// the core around it. This is the headless path: it needs no
  /// Firebase, so it works in an engine started by the SMS receiver.
  ///
  /// Fees come from the on-disk tariff cache only, never the network.
  static Future<CaptureCore> open({
    NudgeNotifier? nudgeNotifier,
    SecureStore? secureStore,
  }) async {
    final store = secureStore ?? SecureStore();
    final passphrase = await store.dbPassphrase();
    final userId = await store.userId();
    final db = AppDatabase(openEncryptedConnection(passphrase: passphrase));
    return create(
      db: db,
      userId: userId,
      fees: CachedFeeScheduleRepository(secureStore: store),
      nudgeNotifier: nudgeNotifier,
    );
  }

  /// How many one-tap category buttons a nudge offers. Android shows at
  /// most three actions.
  static const suggestionCount = 3;

  /// The categories the user spends in most, as notification buttons.
  /// Income categories are skipped, and so is the fee category, which the
  /// pipeline fills in by itself and would otherwise top the list.
  static Future<List<NudgeAction>> _suggestCategories(
    TransactionRepository transactions,
    CategoryRepository categories,
  ) async {
    final ids = await transactions.mostUsedExpenseCategoryIds(
      since: DateTime.now().subtract(const Duration(days: 90)),
    );
    if (ids.isEmpty) return const [];
    final byId = {for (final c in await categories.getAll()) c.id: c};
    final actions = <NudgeAction>[];
    for (final id in ids) {
      final category = byId[id];
      if (category == null || !category.isExpense) continue;
      if (category.name == 'Fees/Charges') continue;
      actions.add(NudgeAction(categoryId: id, label: category.name));
      if (actions.length == suggestionCount) break;
    }
    return actions;
  }

  /// Every expense category, for the floating card's dropdown: sub
  /// categories are labelled with their parent so two "Other"s can be
  /// told apart, and the fee category (filled in by the pipeline) is left
  /// out.
  static Future<List<NudgeAction>> _categoryOptions(
    CategoryRepository categories,
  ) async {
    final all = await categories.getAll();
    final byId = {for (final c in all) c.id: c};
    final options = <NudgeAction>[];
    for (final category in all) {
      if (!category.isExpense || category.name == 'Fees/Charges') continue;
      final parent = byId[category.parentId];
      options.add(
        NudgeAction(
          categoryId: category.id,
          label: parent == null
              ? category.name
              : '${parent.name} / ${category.name}',
        ),
      );
    }
    options.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return options;
  }

  /// Files [transactionId] under [categoryId], confirms it, and teaches
  /// the merchant rule so the next payment there is categorized on
  /// arrival. The same steps as categorizing from the Review Inbox.
  Future<void> categorize(String transactionId, String categoryId) async {
    final transaction = await transactions.byId(transactionId);
    if (transaction == null) return;
    await transactions.updateFields(
      transactionId,
      categoryId: categoryId,
      status: TxStatus.confirmed,
    );
    await merchantCategorizer.learnFrom(
      merchant: transaction.merchant,
      categoryId: categoryId,
    );
  }

  final AppDatabase db;
  final AccountRepository accounts;
  final CategoryRepository categories;
  final TransactionRepository transactions;
  final RawCaptureRepository rawCaptures;
  final BudgetPeriodRepository budgetPeriods;
  final SettingsRepository settings;
  final CustomSenderRepository customSenders;
  final MerchantCategoryRuleRepository merchantCategoryRules;
  final NudgeSettingsRepository nudgeSettings;
  final ParserRegistry registry;
  final MerchantCategorizer merchantCategorizer;
  final CaptureService captureService;
  final CaptureNudger captureNudger;

  Future<void> dispose() async {
    await captureNudger.dispose();
    await db.close();
  }
}
