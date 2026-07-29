import 'dart:async';

/// Where the user stands with respect to app access.
enum AuthStatus {
  /// Nothing resolved yet — the splash is still up.
  unknown,

  /// No credential has ever been set. The app is usable; the user
  /// simply has not turned the lock on.
  unregistered,

  /// A credential exists and has not been satisfied this session.
  locked,

  /// Access granted.
  authenticated,
}

/// The contract the app is written against, so the identity mechanism
/// can change without touching a single cubit or view.
///
/// Today the only implementation is `AppLockRepository` — a local
/// PIN/biometric gate with no network involved, which is what a
/// local-first encrypted finance app actually needs. A Google OAuth
/// implementation can be added later by satisfying this same interface
/// and swapping the wiring in `AppServices`; `AuthGate` and `AuthCubit`
/// would not change.
///
/// Note what this deliberately does *not* include: any notion of the
/// credential unlocking the database. See `AppLockRepository` for why.
abstract interface class AuthRepository {
  /// The current status, available synchronously for the first frame.
  AuthStatus get status;

  /// Status transitions. Broadcast — the gate and the settings page
  /// both listen.
  Stream<AuthStatus> get changes;

  /// Resolves the initial status from storage.
  Future<AuthStatus> load();

  /// Drops back to [AuthStatus.locked], if a credential exists.
  Future<void> lock();

  /// Forgets the credential entirely, leaving the app unlocked and
  /// [AuthStatus.unregistered].
  Future<void> signOut();

  Future<void> dispose();
}

/// Outcome of an unlock attempt.
sealed class UnlockResult {
  const UnlockResult();
}

class UnlockSucceeded extends UnlockResult {
  const UnlockSucceeded();
}

class UnlockRejected extends UnlockResult {
  const UnlockRejected({required this.attemptsRemaining});

  final int attemptsRemaining;
}

/// Too many wrong attempts; the PIN path is closed until [retryAt].
class UnlockThrottled extends UnlockResult {
  const UnlockThrottled({required this.retryAt});

  final DateTime retryAt;
}

/// The user dismissed the biometric prompt, or the sensor refused.
/// Distinct from [UnlockRejected] because it must not burn an attempt.
class UnlockDismissed extends UnlockResult {
  const UnlockDismissed();
}
