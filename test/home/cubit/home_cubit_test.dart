import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/home/home.dart';

import '../../support/corpus.dart';
import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  HomeCubit buildCubit() => HomeCubit(
    transactions: services.transactions,
    rawCaptures: services.rawCaptures,
    smsSync: services.smsSync,
  );

  group('HomeCubit', () {
    test('starts on the activity tab with no badge', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.tabIndex, 0);
      expect(cubit.state.pendingCount, 0);
      expect(cubit.state.captureStatus, CaptureStatus.idle);
    });

    blocTest<HomeCubit, HomeState>(
      'changes tab',
      build: buildCubit,
      act: (cubit) => cubit.tabSelected(2),
      expect: () => const [HomeState(tabIndex: 2)],
    );

    blocTest<HomeCubit, HomeState>(
      'badges an unreadable capture',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture('Airtel: your bundle expires tomorrow.'),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.watchPendingCount(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        expect(cubit.state.failedCaptureCount, 1);
        expect(cubit.state.pendingCount, 1);
      },
    );

    blocTest<HomeCubit, HomeState>(
      'badges a duplicate suspect',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.withdrawal),
        );
        await services.captureService.ingest(
          Corpus.capture(
            'You have withdrawn ZMW 200.00 from 20068466 FELIX MONDE. '
            'Bal is ZMW 55.23. TID: CO260727.1958.D21999.',
            receivedAt: DateTime(2026, 7, 28, 9, 45),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.watchPendingCount(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) => expect(cubit.state.needsReviewCount, 1),
    );

    blocTest<HomeCubit, HomeState>(
      'a cleanly parsed message raises no badge',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.paymentTillNamed),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.watchPendingCount(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) => expect(cubit.state.pendingCount, 0),
    );

    blocTest<HomeCubit, HomeState>(
      'reports capture as listening once the backfill completes',
      build: buildCubit,
      act: (cubit) => cubit.startCapture(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) => expect(
        cubit.state.captureStatus,
        CaptureStatus.listening,
        reason:
            'The default test bridge grants permission and returns no '
            'messages, which is a successful empty backfill',
      ),
    );
  });
}
