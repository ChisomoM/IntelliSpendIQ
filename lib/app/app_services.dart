import 'package:intellispendiq/bootstrap.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/db/connection.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/custom_sender_repository.dart';
import 'package:intellispendiq/data/repositories/label_repository.dart';
import 'package:intellispendiq/data/repositories/overall_budget_repository.dart';
import 'package:intellispendiq/data/repositories/payee_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/ai_provider.dart';
import 'package:intellispendiq/domain/ai/anthropic_chat_provider.dart';
import 'package:intellispendiq/domain/ai/anthropic_claude_provider.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/domain/services/backup_service.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';
import 'package:intellispendiq/domain/services/dedupe_service.dart';
import 'package:intellispendiq/domain/services/finance_chat_service.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';
import 'package:intellispendiq/platform/biometric_authenticator.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';
import 'package:intellispendiq/platform/deep_link_source.dart';

/// Composition root: builds the encrypted database and every repository
/// and service the app needs, wired together once at startup.
class AppServices {
  AppServices._({
    required this.db,
    required this.userId,
    required this.flavor,
    required this.secureStore,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.rawCaptures,
    required this.overallBudgets,
    required this.payees,
    required this.labels,
    required this.settings,
    required this.customSenders,
    required this.appLock,
    required this.registry,
    required this.captureService,
    required this.smsSync,
    required this.voicePipeline,
    required this.aiProvider,
    required this.chatProvider,
    required this.financeChat,
    required this.backupService,
    required this.captureBridge,
    required this.deepLinkSource,
  });

  /// Opens the SQLCipher-encrypted database, seeds first-run data, and
  /// wires the services. The passphrase and user id come from
  /// Keystore-backed storage and are generated on first launch.
  static Future<AppServices> bootstrap({
    required AppFlavor flavor,
    SecureStore? secureStore,
  }) async {
    final store = secureStore ?? SecureStore();
    final passphrase = await store.dbPassphrase();
    final userId = await store.userId();

    final db = AppDatabase(openEncryptedConnection(passphrase: passphrase));
    return _wire(db: db, userId: userId, store: store, flavor: flavor);
  }

  /// Wires services around an already-open database — used by tests with
  /// an in-memory executor.
  static Future<AppServices> forDatabase({
    required AppDatabase db,
    required String userId,
    required SecureStore secureStore,
    CaptureBridge? captureBridge,
    AiProvider? aiProvider,
    ChatProvider? chatProvider,
    BiometricAuthenticator? biometrics,
    DeepLinkSource? deepLinkSource,
    AppFlavor flavor = AppFlavor.development,
  }) => _wire(
    db: db,
    userId: userId,
    store: secureStore,
    captureBridge: captureBridge,
    aiProvider: aiProvider,
    chatProvider: chatProvider,
    biometrics: biometrics,
    deepLinkSource: deepLinkSource,
    flavor: flavor,
  );

  static Future<AppServices> _wire({
    required AppDatabase db,
    required String userId,
    required SecureStore store,
    required AppFlavor flavor,
    CaptureBridge? captureBridge,
    AiProvider? aiProvider,
    ChatProvider? chatProvider,
    BiometricAuthenticator? biometrics,
    DeepLinkSource? deepLinkSource,
  }) async {
    final accounts = AccountRepository(db, userId: userId);
    final categories = CategoryRepository(db, userId: userId);
    final transactions = TransactionRepository(db, userId: userId);
    final rawCaptures = RawCaptureRepository(db, userId: userId);
    final overallBudgets = OverallBudgetRepository(db, userId: userId);
    final payees = PayeeRepository(db, userId: userId);
    final labels = LabelRepository(db, userId: userId);
    final settings = SettingsRepository(db);
    final customSenders = CustomSenderRepository(db, userId: userId);

    // Day-one seeds (plan §6.2): categories and the default Airtel Money
    // account. Both are no-ops after the first launch.
    await categories.ensureSeeds();
    await accounts.ensureDefaultAccount();

    final registry = ParserRegistry()
      ..setCustomSenders({
        for (final sender in await customSenders.getAll())
          sender.senderId: sender.providerKey,
      });
    final captureService = CaptureService(
      registry: registry,
      rawCaptures: rawCaptures,
      transactions: transactions,
      accounts: accounts,
      categories: categories,
      dedupe: DedupeService(transactions),
    );
    final bridge = captureBridge ?? CaptureBridge();
    final ai = aiProvider ?? AnthropicClaudeProvider(secureStore: store);
    final chat = chatProvider ?? AnthropicChatProvider(secureStore: store);
    final financeChatService = FinanceChatService(
      provider: chat,
      transactions: transactions,
      accounts: accounts,
      categories: categories,
    );
    final backupService = BackupService(
      transactions: transactions,
      accounts: accounts,
      categories: categories,
      overallBudgets: overallBudgets,
      payees: payees,
      labels: labels,
    );

    return AppServices._(
      db: db,
      userId: userId,
      flavor: flavor,
      secureStore: store,
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      rawCaptures: rawCaptures,
      overallBudgets: overallBudgets,
      payees: payees,
      labels: labels,
      settings: settings,
      customSenders: customSenders,
      appLock: AppLockRepository(
        secureStore: store,
        settings: settings,
        biometrics: biometrics ?? LocalAuthBiometrics(),
      ),
      registry: registry,
      captureService: captureService,
      smsSync: SmsSyncService(
        bridge: bridge,
        captureService: captureService,
        registry: registry,
        settings: settings,
      ),
      voicePipeline: VoicePipeline(
        aiProvider: ai,
        rawCaptures: rawCaptures,
        transactions: transactions,
        accounts: accounts,
        categories: categories,
      ),
      aiProvider: ai,
      chatProvider: chat,
      financeChat: financeChatService,
      backupService: backupService,
      captureBridge: bridge,
      deepLinkSource: deepLinkSource ?? AppLinksSource(),
    );
  }

  final AppDatabase db;
  final String userId;
  final AppFlavor flavor;
  final SecureStore secureStore;
  final AccountRepository accounts;
  final CategoryRepository categories;
  final TransactionRepository transactions;
  final RawCaptureRepository rawCaptures;
  final OverallBudgetRepository overallBudgets;
  final PayeeRepository payees;
  final LabelRepository labels;
  final SettingsRepository settings;
  final CustomSenderRepository customSenders;
  final AppLockRepository appLock;
  final ParserRegistry registry;
  final CaptureService captureService;
  final SmsSyncService smsSync;
  final VoicePipeline voicePipeline;
  final AiProvider aiProvider;
  final ChatProvider chatProvider;
  final FinanceChatService financeChat;
  final BackupService backupService;
  final CaptureBridge captureBridge;
  final DeepLinkSource deepLinkSource;

  Future<void> dispose() async {
    await smsSync.dispose();
    await appLock.dispose();
    await db.close();
  }
}
