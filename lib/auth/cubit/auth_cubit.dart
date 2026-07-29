import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/repositories/auth_repository.dart';

part 'auth_state.dart';

/// Owns the app-wide access decision. Provided above `AuthGate`, so a
/// single instance survives every navigation.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._auth) : super(const AuthState());

  final AppLockRepository _auth;
  StreamSubscription<AuthStatus>? _subscription;

  /// Resolves the stored credential and starts mirroring the
  /// repository. Called once, from the gate.
  Future<void> load() async {
    _subscription ??= _auth.changes.listen(
      (status) => emit(
        state.copyWith(
          status: status,
          // A fresh lock must not inherit the previous screen's error.
          pin: '',
        ),
      ),
    );

    final status = await _auth.load();
    emit(
      state.copyWith(
        status: status,
        canUseBiometrics: await _auth.canUseBiometrics,
      ),
    );
  }

  // copyWith clears errorMessage and attemptsRemaining unless they are
  // passed, so omitting them here is what resets the previous failure.
  void pinChanged(String value) => emit(state.copyWith(pin: value));

  /// Verifies the typed PIN. The repository owns the throttle, so this
  /// only has to translate the outcome into something the view renders.
  Future<void> submitPin() async {
    if (state.submitting || state.pin.isEmpty) return;
    emit(state.copyWith(submitting: true));

    final result = await _auth.unlockWithPin(state.pin);
    _applyResult(result);
  }

  Future<void> unlockWithBiometrics() async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));

    final result = await _auth.unlockWithBiometrics();
    // A dismissed prompt is not a failure worth shouting about; the
    // user simply chose the PIN instead.
    if (result is UnlockDismissed) {
      emit(state.copyWith(submitting: false));
      return;
    }
    _applyResult(result);
  }

  void _applyResult(UnlockResult result) {
    switch (result) {
      case UnlockSucceeded():
        // The status stream drives the transition; just clear the form.
        emit(state.copyWith(submitting: false, pin: ''));
      case UnlockRejected(:final attemptsRemaining):
        emit(
          state.copyWith(
            submitting: false,
            pin: '',
            attemptsRemaining: attemptsRemaining,
            errorMessage: 'Incorrect PIN. $attemptsRemaining left.',
          ),
        );
      case UnlockThrottled(:final retryAt):
        emit(
          state.copyWith(
            submitting: false,
            pin: '',
            retryAt: retryAt,
            errorMessage: 'Too many attempts. Try again shortly.',
          ),
        );
      case UnlockDismissed():
        emit(state.copyWith(submitting: false));
    }
  }

  /// Re-locks — used by the settings page and by backgrounding.
  Future<void> lock() => _auth.lock();

  /// Fire-and-forget wrappers for button callbacks, which may not
  /// discard a future (`discarded_futures`).
  void loadUnawaited() => unawaited(load());

  void submitPinUnawaited() => unawaited(submitPin());

  void unlockWithBiometricsUnawaited() => unawaited(unlockWithBiometrics());

  void lockUnawaited() => unawaited(lock());

  /// Refreshes what the lock screen may offer, after the user toggles
  /// biometrics in settings.
  Future<void> refreshBiometrics() async =>
      emit(state.copyWith(canUseBiometrics: await _auth.canUseBiometrics));

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
