import 'package:intellispendiq/config/anthropic_api_key.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';

/// Compile-time `ANTHROPIC_API_KEY` from `secrets.json` wins. A leftover
/// Keystore value is only a fallback for installs that never received
/// the dart-define.
Future<String?> resolveAnthropicApiKey(SecureStore store) async {
  if (anthropicApiKeyFromCode.isNotEmpty) return anthropicApiKeyFromCode;
  final stored = await store.anthropicApiKey();
  if (stored != null && stored.isNotEmpty) return stored;
  return null;
}
