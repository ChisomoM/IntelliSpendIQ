import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/features/review/review_inbox_page.dart';

import '../support/corpus.dart';
import '../support/test_harness.dart';

/// Widget-level checks that the Review Inbox surfaces what the capture
/// pipeline routes to it. The database is opened inside each test body
/// rather than in `setUp`, which deadlocks the widget tester.
void main() {
  Future<AppServices> pumpInbox(WidgetTester tester) async {
    final services = await createTestServices();
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ReviewInboxPage()),
      ),
    );
    // pumpAndSettle would spin forever while a loading indicator is on
    // screen, so pump explicit frames instead.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return services;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows inbox zero when there is nothing to review', (
    tester,
  ) async {
    final services = await pumpInbox(tester);

    expect(find.text('Nothing to review'), findsOneWidget);

    await services.dispose();
  });

  testWidgets('an unreadable message keeps its original text on screen', (
    tester,
  ) async {
    const body = 'Airtel: your data bundle expires tomorrow.';
    final services = await createTestServices();
    await services.captureService.ingest(Corpus.capture(body));

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ReviewInboxPage()),
      ),
    );
    await settle(tester);

    expect(find.text('Could not read'), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);

    await services.dispose();
  });

  testWidgets('keeping both duplicates clears the inbox without deleting', (
    tester,
  ) async {
    final services = await createTestServices();
    await services.captureService.ingest(Corpus.capture(Corpus.withdrawal));
    await services.captureService.ingest(
      Corpus.capture(
        'You have withdrawn ZMW 200.00 from 20068466 FELIX MONDE. '
        'Bal is ZMW 55.23. TID: CO260727.1958.D21999.',
        receivedAt: DateTime(2026, 7, 28, 9, 45),
      ),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ReviewInboxPage()),
      ),
    );
    await settle(tester);

    expect(find.text('Possible duplicates'), findsOneWidget);
    expect(find.text('Discard duplicate'), findsOneWidget);

    await tester.tap(find.text('Keep both'));
    // The tap starts a real database write, which the widget tester's
    // fake clock will not drive on its own.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);

    // That both rows survive is asserted in the capture-service tests,
    // where database reads are not subject to the widget tester's clock.
    expect(find.text('Nothing to review'), findsOneWidget);

    await services.dispose();
  });
}
