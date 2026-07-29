import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/auth/auth.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';
import 'package:intellispendiq/splash/splash.dart';

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
      biometrics: FakeBiometrics(available: false),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await services.dispose();
  });

  /// The thing the gate is protecting.
  const secret = Text('protected content');

  Widget wrap() => RepositoryProvider<AppLockRepository>.value(
    value: repository,
    child: BlocProvider(
      create: (_) => AuthCubit(repository),
      child: const MaterialApp(home: AuthGate(child: secret)),
    ),
  );

  /// Advances frames without `pumpAndSettle`, which never settles while
  /// the splash spinner is animating.
  Future<void> tick(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('AuthGate', () {
    testWidgets('shows the splash before the status is known', (tester) async {
      await tester.pumpWidget(wrap());
      // No tick: this is the very first frame, before load() resolves.

      expect(find.byType(SplashView), findsOneWidget);
      expect(find.text('protected content'), findsNothing);
    });

    testWidgets('shows the app when no PIN has been set', (tester) async {
      await tester.pumpWidget(wrap());
      await tick(tester);

      expect(find.text('protected content'), findsOneWidget);
      expect(find.byType(LockScreenPage), findsNothing);
    });

    testWidgets('hides the app behind the lock when a PIN exists', (
      tester,
    ) async {
      await repository.setPin('1234');

      await tester.pumpWidget(wrap());
      await tick(tester);

      expect(find.byType(LockScreenPage), findsOneWidget);
      expect(
        find.text('protected content'),
        findsNothing,
        reason: 'Locked content must not be built, not merely covered',
      );
    });

    testWidgets('reveals the app after the correct PIN', (tester) async {
      await repository.setPin('1234');

      await tester.pumpWidget(wrap());
      await tick(tester);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Unlock'));
      await tick(tester);

      expect(find.text('protected content'), findsOneWidget);
      expect(find.byType(LockScreenPage), findsNothing);
    });

    testWidgets('stays locked after a wrong PIN', (tester) async {
      await repository.setPin('1234');

      await tester.pumpWidget(wrap());
      await tick(tester);

      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Unlock'));
      await tick(tester);

      expect(find.byType(LockScreenPage), findsOneWidget);
      expect(find.text('protected content'), findsNothing);
      expect(find.textContaining('Incorrect PIN'), findsOneWidget);
    });

    testWidgets('does not offer biometrics when they are unavailable', (
      tester,
    ) async {
      await repository.setPin('1234');
      await repository.setBiometricsEnabled(enabled: true);

      await tester.pumpWidget(wrap());
      await tick(tester);

      expect(
        find.text('Use biometrics'),
        findsNothing,
        reason: 'The opt-in alone must not offer a sensor that is gone',
      );
    });
  });
}
