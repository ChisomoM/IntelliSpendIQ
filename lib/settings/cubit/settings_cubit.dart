import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/config/resolve_anthropic_api_key.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';

part 'settings_state.dart';

/// Backs the settings screen's security and AI sections.
///
/// Appearance is not here — `ThemeCubit` owns that, because the theme
/// has to be readable from above this screen.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._auth, this._secureStore) : super(const SettingsState());

  final AppLockRepository _auth;
  final SecureStore _secureStore;

  Future<void> load() async {
    final apiKey = await resolveAnthropicApiKey(_secureStore);
    emit(
      SettingsState(
        status: SettingsStatus.loaded,
        pinSet: await _auth.isPinSet,
        biometricsAvailable: await _auth.biometricsAvailable(),
        biometricsEnabled: await _auth.biometricsEnabled,
        anthropicApiKeyConfigured: apiKey != null && apiKey.isNotEmpty,
      ),
    );
  }

  Future<void> setBiometricsEnabled({required bool enabled}) async {
    await _auth.setBiometricsEnabled(enabled: enabled);
    await load();
  }

  /// Turns the lock off entirely and forgets the PIN.
  Future<void> disableLock() async {
    await _auth.signOut();
    await load();
  }

  /// Persists the Anthropic key in Keystore. Empty / whitespace clears it.
  Future<void> saveAnthropicApiKey(String value) async {
    final trimmed = value.trim();
    await _secureStore.setAnthropicApiKey(
      trimmed.isEmpty ? null : trimmed,
    );
    await load();
  }

  Future<void> clearAnthropicApiKey() async {
    await _secureStore.setAnthropicApiKey(null);
    await load();
  }

  void loadUnawaited() => unawaited(load());
}
