import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';

part 'settings_state.dart';

/// Backs the settings screen's security section.
///
/// Appearance is not here — `ThemeCubit` owns that, because the theme
/// has to be readable from above this screen.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._auth) : super(const SettingsState());

  final AppLockRepository _auth;

  Future<void> load() async {
    emit(
      SettingsState(
        status: SettingsStatus.loaded,
        pinSet: await _auth.isPinSet,
        biometricsAvailable: await _auth.biometricsAvailable(),
        biometricsEnabled: await _auth.biometricsEnabled,
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

  void loadUnawaited() => unawaited(load());
}
