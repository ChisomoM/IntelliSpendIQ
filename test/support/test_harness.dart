import 'package:drift/native.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/identity_repository.dart';
import 'package:intellispendiq/data/repositories/license_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/ai_provider.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/licensing/entitlement.dart';
import 'package:intellispendiq/platform/biometric_authenticator.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';
import 'package:intellispendiq/platform/deep_link_source.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

/// Builds [AppServices] over an in-memory database so pipeline tests run
/// without a device, a Keystore, or SQLCipher.
Future<AppServices> createTestServices({
  AiProvider? aiProvider,
  ChatProvider? chatProvider,
  CaptureBridge? captureBridge,
  SecureStore? secureStore,
  BiometricAuthenticator? biometrics,
  DeepLinkSource? deepLinkSource,
  IdentityRepository? identity,
  LicenseRepository? license,
}) async {
  final store = secureStore ?? FakeSecureStore();
  final db = AppDatabase(NativeDatabase.memory());
  return AppServices.forDatabase(
    db: db,
    userId: 'test-user',
    secureStore: store,
    aiProvider: aiProvider,
    chatProvider: chatProvider ?? FakeChatProvider(),
    // Without these the real implementations would reach for platform
    // channels and throw MissingPluginException off-device.
    captureBridge: captureBridge ?? FakeCaptureBridge(),
    biometrics: biometrics ?? FakeBiometrics(available: false),
    deepLinkSource: deepLinkSource ?? FakeDeepLinkSource(),
    identity: identity ?? FakeIdentityRepository(),
    license: license ?? FakeLicenseRepository(store: store),
  );
}

/// In-memory stand-in for the Keystore. Public so auth tests can hold a
/// reference and assert on what was stored.
class FakeSecureStore implements SecureStore {
  String? appLock;
  String? anthropicKey;
  LicenseSnapshot? licenseCache;

  @override
  Future<String> dbPassphrase() async => 'test-passphrase';

  @override
  Future<String> userId() async => 'test-user';

  @override
  Future<String?> anthropicApiKey() async => anthropicKey;

  @override
  Future<void> setAnthropicApiKey(String? value) async {
    anthropicKey = (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<String?> appLockCredential() async => appLock;

  @override
  Future<void> setAppLockCredential(String? value) async => appLock = value;

  @override
  Future<LicenseSnapshot?> readLicenseCache() async => licenseCache;

  @override
  Future<void> writeLicenseCache(LicenseSnapshot snapshot) async {
    licenseCache = snapshot;
  }

  @override
  Future<void> clearLicenseCache() async => licenseCache = null;
}

/// Biometric sensor stand-in. [available] models a device with
/// enrolments; [succeeds] models what the user does at the prompt.
class FakeBiometrics implements BiometricAuthenticator {
  FakeBiometrics({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  int promptCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    promptCount++;
    return succeeds;
  }
}

/// Feeds deep links without the platform channel.
class FakeDeepLinkSource implements DeepLinkSource {
  FakeDeepLinkSource({this.initial});

  final Uri? initial;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> links() => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);

  Future<void> close() => _controller.close();
}

/// Stands in for the Android capture bridge. Permission is granted and
/// the inbox is whatever the test supplies.
class FakeCaptureBridge implements CaptureBridge {
  FakeCaptureBridge({this.inbox = const [], this.permission = true});

  final List<CaptureInput> inbox;
  final bool permission;
  final readCalls = <int>[];
  final _events = StreamController<CaptureInput>.broadcast();

  @override
  Future<bool> hasSmsPermission() async => permission;

  @override
  Future<bool> requestSmsPermission() async => permission;

  @override
  Future<bool> isNotificationAccessGranted() async => false;

  @override
  Future<void> requestNotificationAccess() async {}

  @override
  Future<List<CaptureInput>> readInboxSince(int sinceMs) async {
    readCalls.add(sinceMs);
    return inbox
        .where((m) => m.receivedAt.millisecondsSinceEpoch >= sinceMs)
        .toList();
  }

  @override
  Stream<CaptureInput> events() => _events.stream;

  void emit(CaptureInput input) => _events.add(input);

  Future<void> close() => _events.close();
}

/// AI provider that returns a scripted extraction, for exercising the
/// voice confidence routing without a network call.
class FakeAiProvider implements AiProvider {
  FakeAiProvider({this.extraction, this.error, this.configured = true});

  final TransactionExtraction? extraction;
  final String? error;
  final bool configured;

  @override
  Future<bool> get isConfigured async => configured;

  @override
  Future<TransactionExtraction> extractTransaction({
    required String transcript,
    String locale = 'en',
  }) async {
    if (error != null) throw AiExtractionException(error!);
    return extraction!;
  }
}

class MockAiProvider extends Mock implements AiProvider {}

/// Chat provider that replays a scripted queue of completions, for
/// exercising `FinanceChatService`'s tool-use loop without a network
/// call. Each `complete` call consumes the next scripted response and
/// records the messages it was sent, so tests can assert on both sides.
class FakeChatProvider implements ChatProvider {
  FakeChatProvider({this.configured = true, List<ChatCompletion>? responses})
    : responses = responses ?? [];

  final bool configured;
  final List<ChatCompletion> responses;
  final calls = <List<Map<String, dynamic>>>[];
  var _next = 0;

  @override
  Future<bool> get isConfigured async => configured;

  @override
  Future<ChatCompletion> complete({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    calls.add(messages);
    if (_next >= responses.length) {
      throw StateError(
        'FakeChatProvider: no scripted response for call #$_next',
      );
    }
    return responses[_next++];
  }
}

/// In-memory Firebase Auth stand-in for widget / pipeline tests.
class FakeIdentityRepository implements IdentityRepository {
  FakeIdentityRepository({IdentityUser? user}) : _user = user;

  IdentityUser? _user;
  final _controller = StreamController<IdentityUser?>.broadcast();

  @override
  IdentityUser? get currentUser => _user;

  @override
  Stream<IdentityUser?> get authStateChanges => _controller.stream;

  @override
  Future<IdentityUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _user = IdentityUser(
      uid: 'uid-${email.hashCode}',
      email: email,
      displayName: displayName,
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<IdentityUser> signIn({
    required String email,
    required String password,
  }) async {
    _user = IdentityUser(uid: 'uid-${email.hashCode}', email: email);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<IdentityUser> signInWithGoogle() async {
    _user = const IdentityUser(
      uid: 'uid-google',
      email: 'google@example.com',
      displayName: 'Google User',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeLicenseRepository implements LicenseRepository {
  FakeLicenseRepository({required SecureStore store}) : _store = store;

  final SecureStore _store;

  @override
  Future<LicenseSnapshot?> readCache() => _store.readLicenseCache();

  @override
  Future<void> clearCache() => _store.clearLicenseCache();

  @override
  Future<LicenseSnapshot> ensureLicense({
    required IdentityUser user,
    String? appVersion,
  }) async {
    final existing = await readCache();
    if (existing != null && existing.uid == user.uid) return existing;
    final now = DateTime.now().toUtc();
    final trialEndsAt = now.add(EntitlementEvaluator.trialDuration);
    final snapshot = LicenseSnapshot(
      uid: user.uid,
      status: 'approved',
      trialEndsAt: trialEndsAt,
      subscriptionActive: false,
      graceEndsAt: EntitlementEvaluator.computeGraceEndsAt(
        trialEndsAt: trialEndsAt,
        subscriptionActive: false,
      ),
      checkedAt: now,
      email: user.email,
      displayName: user.displayName,
    );
    await _store.writeLicenseCache(snapshot);
    return snapshot;
  }

  @override
  Future<LicenseSnapshot?> refreshIfOnline({IdentityUser? user}) async {
    if (user == null) return readCache();
    return ensureLicense(user: user);
  }
}
