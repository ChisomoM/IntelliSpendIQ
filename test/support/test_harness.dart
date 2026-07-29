import 'dart:async';

import 'package:drift/native.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/ai_provider.dart';
import 'package:intellispendiq/domain/ai/chat_provider.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/platform/biometric_authenticator.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';
import 'package:intellispendiq/platform/deep_link_source.dart';
import 'package:mocktail/mocktail.dart';

/// Builds [AppServices] over an in-memory database so pipeline tests run
/// without a device, a Keystore, or SQLCipher.
Future<AppServices> createTestServices({
  AiProvider? aiProvider,
  ChatProvider? chatProvider,
  CaptureBridge? captureBridge,
  SecureStore? secureStore,
  BiometricAuthenticator? biometrics,
  DeepLinkSource? deepLinkSource,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  return AppServices.forDatabase(
    db: db,
    userId: 'test-user',
    secureStore: secureStore ?? FakeSecureStore(),
    aiProvider: aiProvider,
    chatProvider: chatProvider ?? FakeChatProvider(),
    // Without these the real implementations would reach for platform
    // channels and throw MissingPluginException off-device.
    captureBridge: captureBridge ?? FakeCaptureBridge(),
    biometrics: biometrics ?? FakeBiometrics(available: false),
    deepLinkSource: deepLinkSource ?? FakeDeepLinkSource(),
  );
}

/// In-memory stand-in for the Keystore. Public so auth tests can hold a
/// reference and assert on what was stored.
class FakeSecureStore implements SecureStore {
  String? appLock;

  @override
  Future<String> dbPassphrase() async => 'test-passphrase';

  @override
  Future<String> userId() async => 'test-user';

  @override
  Future<String?> anthropicApiKey() async => null;

  @override
  Future<void> setAnthropicApiKey(String? value) async {}

  @override
  Future<String?> appLockCredential() async => appLock;

  @override
  Future<void> setAppLockCredential(String? value) async => appLock = value;
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
