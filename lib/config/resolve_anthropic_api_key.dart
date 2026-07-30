import 'package:intellispendiq/config/anthropic_api_key.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';

/// Keystore value wins; otherwise the compile-time / embedded key.
Future<String?> resolveAnthropicApiKey(SecureStore store) async {
  final stored = await store.anthropicApiKey();
  if (stored != null && stored.isNotEmpty) return stored;
  return anthropicApiKeyFromCode.isEmpty ? null : anthropicApiKeyFromCode;
}
