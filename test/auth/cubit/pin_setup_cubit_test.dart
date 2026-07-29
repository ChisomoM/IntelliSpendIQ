import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/auth/auth.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late FakeSecureStore store;
  late AppLockRepository repository;

  setUp(() async {
    store = FakeSecureStore();
    services = await createTestServices(secureStore: store);
    repository = AppLockRepository(
      secureStore: store,
      settings: services.settings,
      biometrics: FakeBiometrics(),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await services.dispose();
  });

  group('PinSetupCubit', () {
    blocTest<PinSetupCubit, PinSetupState>(
      'stores the PIN after it is entered twice',
      build: () => PinSetupCubit(repository),
      act: (cubit) async {
        cubit.pinChanged('1234');
        await cubit.submit();
        expect(cubit.state.step, PinSetupStep.confirm);
        expect(cubit.state.entry, isEmpty);

        cubit.pinChanged('1234');
        await cubit.submit();
      },
      verify: (cubit) async {
        expect(cubit.state.status, PinSetupStatus.success);
        expect(await repository.isPinSet, isTrue);
        expect(await repository.verifyPin('1234'), isTrue);
      },
    );

    blocTest<PinSetupCubit, PinSetupState>(
      'restarts from the beginning when the two entries differ',
      build: () => PinSetupCubit(repository),
      act: (cubit) async {
        cubit.pinChanged('1234');
        await cubit.submit();
        cubit.pinChanged('9999');
        await cubit.submit();
      },
      verify: (cubit) async {
        expect(
          cubit.state.step,
          PinSetupStep.choose,
          reason: 'Retyping the confirmation would keep a mistyped PIN',
        );
        expect(cubit.state.chosen, isEmpty);
        expect(cubit.state.errorMessage, isNotNull);
        expect(await repository.isPinSet, isFalse);
      },
    );

    blocTest<PinSetupCubit, PinSetupState>(
      'refuses a PIN that is too short to advance',
      build: () => PinSetupCubit(repository),
      act: (cubit) async {
        cubit.pinChanged('12');
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.step, PinSetupStep.choose);
        expect(cubit.state.errorMessage, isNotNull);
      },
    );

    blocTest<PinSetupCubit, PinSetupState>(
      'asks for the current PIN first when changing it',
      setUp: () async {
        await repository.setPin('1111');
      },
      build: () => PinSetupCubit(repository, requireCurrentPin: true),
      act: (cubit) async {
        expect(cubit.state.step, PinSetupStep.verifyCurrent);

        cubit.pinChanged('1111');
        await cubit.submit();
        expect(cubit.state.step, PinSetupStep.choose);

        cubit.pinChanged('2222');
        await cubit.submit();
        cubit.pinChanged('2222');
        await cubit.submit();
      },
      verify: (cubit) async {
        expect(cubit.state.status, PinSetupStatus.success);
        expect(await repository.verifyPin('2222'), isTrue);
        expect(await repository.verifyPin('1111'), isFalse);
      },
    );

    blocTest<PinSetupCubit, PinSetupState>(
      'will not let a stranger change the PIN without the old one',
      setUp: () async {
        await repository.setPin('1111');
      },
      build: () => PinSetupCubit(repository, requireCurrentPin: true),
      act: (cubit) async {
        cubit.pinChanged('0000');
        await cubit.submit();
      },
      verify: (cubit) async {
        expect(cubit.state.step, PinSetupStep.verifyCurrent);
        expect(cubit.state.errorMessage, isNotNull);
        expect(await repository.verifyPin('1111'), isTrue);
      },
    );
  });
}
