import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/cubit/cubit.dart';
import 'package:intellispendiq/core/app_section.dart';
import 'package:intellispendiq/core/deep_link.dart';

import '../../support/test_harness.dart';

void main() {
  late FakeDeepLinkSource source;

  setUp(() => source = FakeDeepLinkSource());
  tearDown(() async => source.close());

  /// Lets a link emitted on the stream reach the cubit's listener.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('DeepLinkCubit', () {
    test('starts with nothing pending', () {
      final cubit = DeepLinkCubit(source);
      addTearDown(cubit.close);

      expect(cubit.state.hasPending, isFalse);
    });

    blocTest<DeepLinkCubit, DeepLinkState>(
      'parks the link the app was launched from',
      build: () => DeepLinkCubit(
        FakeDeepLinkSource(initial: Uri.parse('intellispendiq://budgets')),
      ),
      act: (cubit) => cubit.start(),
      expect: () => const [
        DeepLinkState(pending: SectionLink(AppSection.budgets)),
      ],
    );

    blocTest<DeepLinkCubit, DeepLinkState>(
      'parks a link that arrives while running',
      build: () => DeepLinkCubit(source),
      act: (cubit) async {
        await cubit.start();
        source.emit(Uri.parse('intellispendiq://transaction/abc'));
        await settle();
      },
      expect: () => const [DeepLinkState(pending: TransactionLink('abc'))],
    );

    blocTest<DeepLinkCubit, DeepLinkState>(
      'drops an unrecognised link instead of parking it',
      build: () => DeepLinkCubit(source),
      act: (cubit) async {
        await cubit.start();
        source
          ..emit(Uri.parse('https://evil.example/review'))
          ..emit(Uri.parse('intellispendiq://nope'));
        await settle();
      },
      expect: () => const <DeepLinkState>[],
      verify: (cubit) => expect(cubit.state.hasPending, isFalse),
    );

    blocTest<DeepLinkCubit, DeepLinkState>(
      'clears the pending link once it has been navigated to',
      build: () => DeepLinkCubit(
        FakeDeepLinkSource(initial: Uri.parse('intellispendiq://add')),
      ),
      act: (cubit) async {
        await cubit.start();
        cubit.consumed();
      },
      expect: () => const [
        DeepLinkState(pending: AddTransactionLink()),
        DeepLinkState(),
      ],
    );

    blocTest<DeepLinkCubit, DeepLinkState>(
      'a second link replaces one that was never consumed',
      build: () => DeepLinkCubit(source),
      act: (cubit) async {
        await cubit.start();
        source.emit(Uri.parse('intellispendiq://review'));
        await settle();
        source.emit(Uri.parse('intellispendiq://reports'));
        await settle();
      },
      verify: (cubit) => expect(
        cubit.state.pending,
        const SectionLink(AppSection.reports),
        reason: 'The newest intent is the one the user just expressed',
      ),
    );
  });
}
