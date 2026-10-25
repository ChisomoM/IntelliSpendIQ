import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/settings/view/cycle_dates_page.dart';

import '../../support/font_guard.dart';
import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  /// Lets real async work (the in-memory database) finish between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openPage(WidgetTester tester) async {
    services = (await tester.runAsync(createTestServices))!;
    addTearDown(() async => tester.runAsync(services.dispose));

    // Payday was yesterday, so today sits inside the current cycle and
    // "Start the next cycle today" is on offer.
    final today = DateTime.now();
    await tester.runAsync(
      () => services.budgetPeriods.updateSchedule(
        cadence: BudgetCadence.payday,
        anchorDay: today.day > 1 ? today.day - 1 : 28,
      ),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<BudgetPeriodRepository>.value(
            value: services.budgetPeriods,
          ),
          RepositoryProvider<TransactionRepository>.value(
            value: services.transactions,
          ),
        ],
        child: const MaterialApp(home: CycleDatesPage()),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'lists the next and current cycle',
    (tester) => ignoringFontFetchErrors(() async {
      await openPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Next cycle'), findsOneWidget);
      expect(find.text('Current cycle'), findsOneWidget);
    }),
  );

  testWidgets(
    'starting the next cycle today saves, refreshes, and says so',
    (tester) => ignoringFontFetchErrors(() async {
      await openPage(tester);
      final today = Iso.formatDateDdMmYyyy(DateTime.now());

      await tester.tap(find.text('Start the next cycle today'));
      await settle(tester);
      expect(find.text('Change cycle dates?'), findsOneWidget);

      await tester.tap(find.text('Change dates'));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Cycle dates updated.'), findsOneWidget);
      // Snack bars queue, so a failure reported after the success message
      // would stay hidden behind it. Dismiss the first and check that
      // nothing is waiting.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).hideCurrentSnackBar();
      await settle(tester);
      expect(find.textContaining('Could not change'), findsNothing);
      // The list reloaded with the next cycle now starting today, and the
      // shortcut is gone because the next cycle already starts today.
      expect(find.textContaining(today), findsWidgets);
      expect(find.text('Start the next cycle today'), findsNothing);
    }),
  );
}
