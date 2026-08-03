import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/design/design.dart';

void main() {
  testWidgets(
    'CategoryStatTiles lays out inside a ListView without throwing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: const [
                CategoryStatTiles(
                  budgetedMinor: 100_000,
                  spentMinor: 40_000,
                  remainingMinor: 60_000,
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('BUDGETED'), findsOneWidget);
      expect(find.text('SPENT'), findsOneWidget);
      expect(find.text('LEFT'), findsOneWidget);
    },
  );
}
