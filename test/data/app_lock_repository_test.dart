import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/repositories/auth_repository.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late FakeSecureStore store;
  late FakeBiometrics biometrics;
  late DateTime now;
  late AppLockRepository repository;

  setUp(() async {
    store = FakeSecureStore();
    biometrics = FakeBiometrics();
    now = DateTime(2026, 7, 29, 9);
    services = await createTestServices(
      secureStore: store,
      biometrics: biometrics,
    );
    repository = AppLockRepository(
      secureStore: store,
      settings: services.settings,
      biometrics: biometrics,
      now: () => now,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await services.dispose();
  });

  group('AppLockRepository', () {
    test('starts unregistered when no PIN was ever set', () async {
      expect(await repository.load(), AuthStatus.unregistered);
      expect(await repository.isPinSet, isFalse);
    });

    test('starts locked once a PIN exists', () async {
      await repository.setPin('1234');

      expect(await repository.load(), AuthStatus.locked);
    });

    test('setting a PIN stores a verifier, never the PIN', () async {
      await repository.setPin('4821');

      expect(store.appLock, isNotNull);
      expect(store.appLock, isNot(contains('4821')));
    });

    test('rejects a PIN that is too short, too long, or not digits', () async {
      for (final bad in ['123', '123456789', 'abcd', '12 34', '']) {
        expect(
          () => repository.setPin(bad),
          throwsArgumentError,
          reason: 'A malformed PIN must never reach storage: "$bad"',
        );
      }
      expect(store.appLock, isNull);
    });

    test('unlocks with the right PIN', () async {
      await repository.setPin('1234');
      await repository.lock();

      expect(await repository.unlockWithPin('1234'), isA<UnlockSucceeded>());
      expect(repository.status, AuthStatus.authenticated);
    });

    test('counts down remaining attempts on a wrong PIN', () async {
      await repository.setPin('1234');
      await repository.lock();

      final first = await repository.unlockWithPin('0000');
      final second = await repository.unlockWithPin('0000');

      expect(
        (first as UnlockRejected).attemptsRemaining,
        AppLockRepository.maxAttempts - 1,
      );
      expect(
        (second as UnlockRejected).attemptsRemaining,
        AppLockRepository.maxAttempts - 2,
      );
      expect(repository.status, AuthStatus.locked);
    });

    test('throttles after the attempt limit, then recovers', () async {
      await repository.setPin('1234');
      await repository.lock();

      for (var i = 0; i < AppLockRepository.maxAttempts - 1; i++) {
        expect(await repository.unlockWithPin('0000'), isA<UnlockRejected>());
      }
      final throttled = await repository.unlockWithPin('0000');
      expect(throttled, isA<UnlockThrottled>());

      // The correct PIN is refused too — otherwise the throttle would
      // be trivially bypassable by guessing right on the next try.
      expect(await repository.unlockWithPin('1234'), isA<UnlockThrottled>());
      expect(repository.status, AuthStatus.locked);

      now = (throttled as UnlockThrottled).retryAt.add(
        const Duration(seconds: 1),
      );
      expect(await repository.unlockWithPin('1234'), isA<UnlockSucceeded>());
      expect(repository.status, AuthStatus.authenticated);
    });

    test('a successful unlock clears the failure count', () async {
      await repository.setPin('1234');
      await repository.lock();

      await repository.unlockWithPin('0000');
      await repository.unlockWithPin('1234');
      await repository.lock();

      final rejected = await repository.unlockWithPin('0000');
      expect(
        (rejected as UnlockRejected).attemptsRemaining,
        AppLockRepository.maxAttempts - 1,
        reason: 'The counter should restart, not resume mid-way',
      );
    });

    test('biometrics are only offered when enabled and available', () async {
      await repository.setPin('1234');

      expect(await repository.canUseBiometrics, isFalse);

      await repository.setBiometricsEnabled(enabled: true);
      expect(await repository.canUseBiometrics, isTrue);

      // An enrolment removed at the OS level revokes the option even
      // though the stored preference still says yes.
      biometrics.available = false;
      expect(await repository.canUseBiometrics, isFalse);
    });

    test('a successful scan unlocks', () async {
      await repository.setPin('1234');
      await repository.setBiometricsEnabled(enabled: true);
      await repository.lock();

      expect(
        await repository.unlockWithBiometrics(),
        isA<UnlockSucceeded>(),
      );
      expect(repository.status, AuthStatus.authenticated);
    });

    test('a dismissed scan does not burn a PIN attempt', () async {
      await repository.setPin('1234');
      await repository.setBiometricsEnabled(enabled: true);
      await repository.lock();
      biometrics.succeeds = false;

      expect(await repository.unlockWithBiometrics(), isA<UnlockDismissed>());

      final rejected = await repository.unlockWithPin('0000');
      expect(
        (rejected as UnlockRejected).attemptsRemaining,
        AppLockRepository.maxAttempts - 1,
        reason: 'Cancelling a fingerprint prompt is not a failed guess',
      );
    });

    test('does not prompt the sensor when biometrics are off', () async {
      await repository.setPin('1234');
      await repository.lock();

      expect(await repository.unlockWithBiometrics(), isA<UnlockDismissed>());
      expect(biometrics.promptCount, 0);
    });

    test('verifyPin checks without unlocking', () async {
      await repository.setPin('1234');
      await repository.lock();

      expect(await repository.verifyPin('1234'), isTrue);
      expect(
        repository.status,
        AuthStatus.locked,
        reason: 'Proving the old PIN when changing it is not an unlock',
      );
      expect(await repository.verifyPin('0000'), isFalse);
    });

    test('signing out forgets the PIN and the biometric opt-in', () async {
      await repository.setPin('1234');
      await repository.setBiometricsEnabled(enabled: true);

      await repository.signOut();

      expect(store.appLock, isNull);
      expect(await repository.biometricsEnabled, isFalse);
      expect(repository.status, AuthStatus.unregistered);
    });

    test('lock is a no-op when there is no PIN to lock behind', () async {
      await repository.load();
      await repository.lock();

      expect(repository.status, AuthStatus.unregistered);
    });

    test('publishes every transition', () async {
      final seen = <AuthStatus>[];
      final subscription = repository.changes.listen(seen.add);

      await repository.load();
      await repository.setPin('1234');
      await repository.lock();
      await repository.unlockWithPin('1234');
      // Broadcast delivery is a microtask; drain it before unsubscribing
      // or the final transition is cancelled out from under us.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(seen, [
        AuthStatus.unregistered,
        AuthStatus.authenticated,
        AuthStatus.locked,
        AuthStatus.authenticated,
      ]);
    });
  });
}
