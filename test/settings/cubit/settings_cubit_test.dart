import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/settings/settings.dart';

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

  SettingsCubit buildCubit() => SettingsCubit(repository, store);

  group('SettingsCubit', () {
    blocTest<SettingsCubit, SettingsState>(
      'reports the lock as off before a PIN is set',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.pinSet, isFalse);
        expect(cubit.state.canOfferBiometrics, isFalse);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'will not offer biometrics without a PIN behind them',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.biometricsAvailable, isTrue);
        expect(
          cubit.state.canOfferBiometrics,
          isFalse,
          reason: 'Biometrics are a shortcut past the PIN, not a substitute',
        );
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'offers biometrics once a PIN exists',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.canOfferBiometrics, isTrue),
    );

    blocTest<SettingsCubit, SettingsState>(
      'hides biometrics on a device without enrolments',
      setUp: () async {
        await repository.setPin('1234');
        biometrics.available = false;
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.pinSet, isTrue);
        expect(cubit.state.canOfferBiometrics, isFalse);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'persists the biometric opt-in',
      setUp: () async {
        await repository.setPin('1234');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.setBiometricsEnabled(enabled: true);
      },
      verify: (cubit) async {
        expect(cubit.state.biometricsEnabled, isTrue);
        expect(await repository.biometricsEnabled, isTrue);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'turning the lock off clears the PIN and the opt-in together',
      setUp: () async {
        await repository.setPin('1234');
        await repository.setBiometricsEnabled(enabled: true);
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.disableLock();
      },
      verify: (cubit) async {
        expect(cubit.state.pinSet, isFalse);
        expect(cubit.state.biometricsEnabled, isFalse);
        expect(store.appLock, isNull);
        expect(
          await repository.biometricsEnabled,
          isFalse,
          reason: 'A stale opt-in would re-enable itself on the next PIN',
        );
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'reports the Anthropic key as missing until one is saved',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.anthropicApiKeyConfigured, isFalse);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'saves the Anthropic key to the secure store',
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.saveAnthropicApiKey('  sk-ant-test  ');
      },
      verify: (cubit) {
        expect(cubit.state.anthropicApiKeyConfigured, isTrue);
        expect(store.anthropicKey, 'sk-ant-test');
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'clears the Anthropic key',
      setUp: () async {
        await store.setAnthropicApiKey('sk-ant-test');
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.clearAnthropicApiKey();
      },
      verify: (cubit) {
        expect(cubit.state.anthropicApiKeyConfigured, isFalse);
        expect(store.anthropicKey, isNull);
      },
    );
  });
}
