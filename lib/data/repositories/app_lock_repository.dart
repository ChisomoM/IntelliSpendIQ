import 'dart:async';
import 'dart:math' as math;

import 'package:intellispendiq/core/pin_hasher.dart';
import 'package:intellispendiq/data/repositories/auth_repository.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/platform/biometric_authenticator.dart';

/// A local PIN + biometric gate over the app UI.
///
/// ## What this protects, and what it does not
///
/// This is a **UI gate, not a crypto gate**. The SQLCipher passphrase
/// stays in the Keystore and the database is opened at startup,
/// before the lock is satisfied.
///
/// That is a deliberate trade, not an oversight. Deriving the database
/// key from the PIN would mean the database is unreadable while the app
/// is locked — and SMS capture writes to it from a broadcast receiver at
/// any hour, locked or not. Priority #1 of this project is never
/// silently dropping a financial event; a lock that made the capture
/// pipeline fail closed would violate it on every message that arrived
/// while the phone was in a pocket.
///
/// So: the data at rest is protected by SQLCipher plus the Android
/// Keystore, and this lock protects the *screen* from someone holding an
/// already-unlocked phone. Those are different threats and both are
/// worth covering.
class AppLockRepository implements AuthRepository {
  AppLockRepository({
    required SecureStore secureStore,
    required SettingsRepository settings,
    required BiometricAuthenticator biometrics,
    DateTime Function()? now,
  }) : _secureStore = secureStore,
       _settings = settings,
       _biometrics = biometrics,
       _now = now ?? DateTime.now;

  final SecureStore _secureStore;
  final SettingsRepository _settings;
  final BiometricAuthenticator _biometrics;
  final DateTime Function() _now;

  static const biometricsEnabledKey = 'app_lock_biometrics_enabled';
  static const _failedAttemptsKey = 'app_lock_failed_attempts';
  static const _retryAtKey = 'app_lock_retry_at_ms';

  /// Wrong PINs tolerated before the cooldown starts.
  static const maxAttempts = 5;

  /// PIN length bounds. Short enough to be typed one-handed, long
  /// enough that the throttle has something to protect.
  static const minPinLength = 4;
  static const maxPinLength = 8;

  final _controller = StreamController<AuthStatus>.broadcast();
  AuthStatus _status = AuthStatus.unknown;

  @override
  AuthStatus get status => _status;

  @override
  Stream<AuthStatus> get changes => _controller.stream;

  @override
  Future<AuthStatus> load() async {
    final credential = await _secureStore.appLockCredential();
    return _emit(
      credential == null ? AuthStatus.unregistered : AuthStatus.locked,
    );
  }

  /// Whether a PIN is currently configured.
  Future<bool> get isPinSet async =>
      await _secureStore.appLockCredential() != null;

  Future<bool> get biometricsEnabled => _settings.getBool(biometricsEnabledKey);

  Future<bool> biometricsAvailable() => _biometrics.isAvailable();

  /// Whether the lock screen should offer the biometric button: the
  /// user opted in *and* the device can still deliver. Enrolments get
  /// removed, so the stored flag alone is not enough.
  Future<bool> get canUseBiometrics async =>
      await biometricsEnabled && await biometricsAvailable();

  Future<void> setBiometricsEnabled({required bool enabled}) =>
      _settings.set(biometricsEnabledKey, '$enabled');

  /// Turns the lock on, or replaces an existing PIN.
  ///
  /// Throws [ArgumentError] if [pin] is not [minPinLength]–
  /// [maxPinLength] digits, so a malformed PIN can never be stored.
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError.value(
        pin,
        'pin',
        'must be $minPinLength-$maxPinLength digits',
      );
    }
    await _secureStore.setAppLockCredential(PinHasher.hash(pin));
    await _resetThrottle();
    _emit(AuthStatus.authenticated);
  }

  static bool isValidPin(String pin) =>
      pin.length >= minPinLength &&
      pin.length <= maxPinLength &&
      RegExp(r'^\d+$').hasMatch(pin);

  /// Checks a PIN without touching the session status or the throttle.
  ///
  /// Used when *changing* the PIN, where proving you know the old one
  /// must not double as an unlock.
  Future<bool> verifyPin(String pin) async {
    final credential = await _secureStore.appLockCredential();
    if (credential == null) return false;
    return PinHasher.verify(pin, credential);
  }

  Future<UnlockResult> unlockWithPin(String pin) async {
    final throttled = await _activeThrottle();
    if (throttled != null) return UnlockThrottled(retryAt: throttled);

    final credential = await _secureStore.appLockCredential();
    if (credential == null) {
      // No PIN set at all — nothing to check against.
      _emit(AuthStatus.unregistered);
      return const UnlockSucceeded();
    }

    if (PinHasher.verify(pin, credential)) {
      await _resetThrottle();
      _emit(AuthStatus.authenticated);
      return const UnlockSucceeded();
    }

    return _recordFailure();
  }

  /// A successful biometric scan is trusted on its own — the OS already
  /// verified the human. It never consumes a PIN attempt.
  Future<UnlockResult> unlockWithBiometrics() async {
    final throttled = await _activeThrottle();
    if (throttled != null) return UnlockThrottled(retryAt: throttled);

    if (!await canUseBiometrics) return const UnlockDismissed();

    final ok = await _biometrics.authenticate(
      reason: 'Unlock IntelliSpendIQ',
    );
    if (!ok) return const UnlockDismissed();

    await _resetThrottle();
    _emit(AuthStatus.authenticated);
    return const UnlockSucceeded();
  }

  @override
  Future<void> lock() async {
    if (await isPinSet) _emit(AuthStatus.locked);
  }

  @override
  Future<void> signOut() async {
    await _secureStore.setAppLockCredential(null);
    await _settings.set(biometricsEnabledKey, 'false');
    await _resetThrottle();
    _emit(AuthStatus.unregistered);
  }

  /// The cooldown deadline if one is in force, else null. Expired
  /// deadlines are cleared as a side effect.
  Future<DateTime?> _activeThrottle() async {
    final retryAtMs = await _settings.getInt(_retryAtKey);
    if (retryAtMs == null) return null;

    final retryAt = DateTime.fromMillisecondsSinceEpoch(retryAtMs);
    if (!_now().isBefore(retryAt)) {
      await _settings.set(_retryAtKey, '');
      return null;
    }
    return retryAt;
  }

  Future<UnlockResult> _recordFailure() async {
    final failures = (await _settings.getInt(_failedAttemptsKey) ?? 0) + 1;
    await _settings.set(_failedAttemptsKey, '$failures');

    final remaining = maxAttempts - failures;
    if (remaining > 0) {
      return UnlockRejected(attemptsRemaining: remaining);
    }

    // 30s after the 5th failure, doubling per extra failure, capped at
    // 15 minutes so a forgetful owner is inconvenienced rather than
    // permanently locked out of their own records.
    final overage = failures - maxAttempts;
    final backoff = Duration(
      seconds: math.min(30 * math.pow(2, overage).toInt(), 900),
    );
    final retryAt = _now().add(backoff);
    await _settings.set(
      _retryAtKey,
      '${retryAt.millisecondsSinceEpoch}',
    );
    return UnlockThrottled(retryAt: retryAt);
  }

  Future<void> _resetThrottle() async {
    await _settings.set(_failedAttemptsKey, '0');
    await _settings.set(_retryAtKey, '');
  }

  AuthStatus _emit(AuthStatus next) {
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
    return next;
  }

  @override
  Future<void> dispose() => _controller.close();
}
