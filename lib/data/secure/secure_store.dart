import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intellispendiq/core/ids.dart';

/// Keystore-backed storage for secrets and identity (D36, D41):
/// the DB passphrase, the stable local user id, and the Anthropic API
/// key. Nothing here ever goes to SharedPreferences or source control.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _dbPassphraseKey = 'db_passphrase';
  static const _userIdKey = 'local_user_id';
  static const _anthropicApiKeyKey = 'anthropic_api_key';
  static const _appLockKey = 'app_lock_credential';

  /// Returns the SQLCipher passphrase, generating a random 256-bit hex
  /// value on first launch.
  Future<String> dbPassphrase() async {
    final existing = await _storage.read(key: _dbPassphraseKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final passphrase = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _dbPassphraseKey, value: passphrase);
    return passphrase;
  }

  /// Stable local user id (UUID) generated at first launch; becomes the
  /// account owner id when Supabase Auth lands (D36).
  Future<String> userId() async {
    final existing = await _storage.read(key: _userIdKey);
    if (existing != null) return existing;
    final id = Ids.newId();
    await _storage.write(key: _userIdKey, value: id);
    return id;
  }

  Future<String?> anthropicApiKey() => _storage.read(key: _anthropicApiKeyKey);

  Future<void> setAnthropicApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _anthropicApiKeyKey);
    } else {
      await _storage.write(key: _anthropicApiKeyKey, value: value);
    }
  }

  /// The serialised app-lock credential, or null when no PIN is set.
  ///
  /// This is a PBKDF2 verifier, never the PIN itself — see
  /// `PinHasher`. Reading it back must not be enough to unlock.
  Future<String?> appLockCredential() => _storage.read(key: _appLockKey);

  Future<void> setAppLockCredential(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _appLockKey);
    } else {
      await _storage.write(key: _appLockKey, value: value);
    }
  }
}
