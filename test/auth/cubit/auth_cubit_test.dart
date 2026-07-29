import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/auth/auth.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/data/repositories/auth_repository.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late FakeSecureStore store;
  late FakeBiometrics biometrics;
  late AppLockRepository repository;

  setUp(() async {
    store = FakeSecureStore();
    biometrics = FakeBiometrics();
    services = await createTestServices(
      secureStore: store,
      biometrics: biometrics,
    );
    repository = AppLockRepository(
      secureStore: store,
      settings: services.settings,
      biometrics: biometrics,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await services.dispose();
  });

  AuthCubit buildCubit() => AuthCubit(repository);

  group('AuthCubit', () {
    test('starts unresolved so the gate can show the splash', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.status, AuthStatus.unknown);
      expect(cubit.state.isResolved, isFalse);
      expect(cubit.state.isUnlocked, isFalse);
    });

    blocTest<AuthCubit, AuthState>(
      'treats a user who never set a PIN as unlocked',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.unregistered);
        expect(
          cubit.state.isUnlocked,
          isTrue,
          reason: 'Not opting into the lock must not lock you out',
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'comes up locked when a PIN exists',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.locked);
        expect(cubit.state.isUnlocked, isFalse);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'unlocks with the right PIN and clears the entry',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        cubit.pinChanged('1234');
        await cubit.submitPin();
      },
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.authenticated);
        expect(cubit.state.isUnlocked, isTrue);
        expect(
          cubit.state.pin,
          isEmpty,
          reason: 'The typed PIN must not linger in memory after use',
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'reports remaining attempts on a wrong PIN',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        cubit.pinChanged('0000');
        await cubit.submitPin();
      },
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.locked);
        expect(
          cubit.state.attemptsRemaining,
          AppLockRepository.maxAttempts - 1,
        );
        expect(cubit.state.errorMessage, isNotNull);
        expect(cubit.state.pin, isEmpty);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'clears the previous error as soon as the user types again',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        cubit.pinChanged('0000');
        await cubit.submitPin();
        cubit.pinChanged('1');
      },
      verify: (cubit) {
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.attemptsRemaining, isNull);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'surfaces the cooldown after too many attempts',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        for (var i = 0; i < AppLockRepository.maxAttempts; i++) {
          cubit.pinChanged('0000');
          await cubit.submitPin();
        }
      },
      verify: (cubit) {
        expect(cubit.state.retryAt, isNotNull);
        expect(cubit.state.status, AuthStatus.locked);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'ignores a submit with an empty field',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.submitPin();
      },
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.locked);
        expect(
          cubit.state.errorMessage,
          isNull,
          reason: 'An accidental tap should not consume an attempt',
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'offers biometrics only once enabled',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        expect(cubit.state.canUseBiometrics, isFalse);

        await repository.setBiometricsEnabled(enabled: true);
        await cubit.refreshBiometrics();
      },
      verify: (cubit) => expect(cubit.state.canUseBiometrics, isTrue),
    );

    blocTest<AuthCubit, AuthState>(
      'unlocks on a successful scan',
      setUp: () async {
        await repository.setPin('1234');
        await repository.setBiometricsEnabled(enabled: true);
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.unlockWithBiometrics();
      },
      verify: (cubit) => expect(cubit.state.status, AuthStatus.authenticated),
    );

    blocTest<AuthCubit, AuthState>(
      'stays quiet when the user dismisses the scan',
      setUp: () async {
        await repository.setPin('1234');
        await repository.setBiometricsEnabled(enabled: true);
        biometrics.succeeds = false;
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.unlockWithBiometrics();
      },
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.locked);
        expect(cubit.state.submitting, isFalse);
        expect(
          cubit.state.errorMessage,
          isNull,
          reason: 'Choosing the PIN instead is not an error worth showing',
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'follows a lock triggered from elsewhere, such as backgrounding',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        cubit.pinChanged('1234');
        await cubit.submitPin();
        await cubit.lock();
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.locked);
        expect(cubit.state.pin, isEmpty);
      },
    );
  });
}
