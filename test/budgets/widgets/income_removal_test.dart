import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/budgets/widgets/widgets.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

import '../../support/font_guard.dart';

void main() {
  const salary = Category(
    id: 'salary',
    name: 'Salary',
    type: CategoryType.income,
    budgetedAmountMinor: 800000,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<Category> categories,
    required void Function(Category, IncomeStatus?) onRemove,
    Map<String, IncomeStatus> status = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              IncomeSummaryCard(
                incomeCategories: categories,
                statusByCategory: status,
                receivedByCategory: const {},
                actualMinor: 0,
                provisionalMinor: 800000,
                onTapRow: (_, _) {},
                onRemoveFromCycle: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'long-pressing an income with an amount offers to remove it from the cycle',
    (tester) => ignoringFontFetchErrors(() async {
      Category? removed;
      IncomeStatus? removedStatus;
      await pumpCard(
        tester,
        categories: const [salary],
        status: const {'salary': IncomeStatus.paid},
        onRemove: (category, status) {
          removed = category;
          removedStatus = status;
        },
      );

      await tester.longPress(find.text('Salary'));
      await tester.pumpAndSettle();
      expect(find.text('Edit income source'), findsOneWidget);
      expect(find.text('Other cycles are not affected'), findsOneWidget);

      await tester.tap(find.text('Remove planned amount from this cycle'));
      await tester.pumpAndSettle();

      expect(removed, salary);
      expect(removedStatus, IncomeStatus.paid);
    }),
  );

  group('showRemoveIncomeDialog', () {
    Future<RemoveIncomeResult?> open(
      WidgetTester tester, {
      required bool isPaid,
    }) async {
      RemoveIncomeResult? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showRemoveIncomeDialog(
                    context,
                    category: salary,
                    amountMinor: 800000,
                    isPaid: isPaid,
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      return result;
    }

    testWidgets(
      'a planned income just confirms, with no option about money received',
      (tester) => ignoringFontFetchErrors(() async {
        await open(tester, isPaid: false);

        expect(find.text('Remove from this cycle?'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.textContaining('"Salary"'), findsOneWidget);
      }),
    );

    testWidgets(
      'a paid income keeps the money received unless the switch is turned on',
      (tester) => ignoringFontFetchErrors(() async {
        await open(tester, isPaid: true);
        final toggle = find.byType(SwitchListTile);
        expect(toggle, findsOneWidget);
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      }),
    );
  });
}
