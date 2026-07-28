import 'package:drift/native.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/ai/ai_provider.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:mocktail/mocktail.dart';

/// Builds [AppServices] over an in-memory database so pipeline tests run
/// without a device, a Keystore, or SQLCipher.
Future<AppServices> createTestServices({AiProvider? aiProvider}) async {
  final db = AppDatabase(NativeDatabase.memory());
  return AppServices.forDatabase(
    db: db,
    userId: 'test-user',
    secureStore: _FakeSecureStore(),
    aiProvider: aiProvider,
  );
}

class _FakeSecureStore implements SecureStore {
  @override
  Future<String> dbPassphrase() async => 'test-passphrase';

  @override
  Future<String> userId() async => 'test-user';

  @override
  Future<String?> anthropicApiKey() async => null;

  @override
  Future<void> setAnthropicApiKey(String? value) async {}
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
