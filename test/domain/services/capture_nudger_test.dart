import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/nudge_settings.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';

import '../../support/test_harness.dart';

class _RecordingNotifier implements NudgeNotifier {
  final shown = <NudgeMessage>[];

  @override
  Future<void> show(NudgeMessage message) async => shown.add(message);
}

void main() {
  // Local wall-clock times, so quiet-hours checks do not depend on the
  // timezone of the machine running the tests.
  final now = DateTime(2026, 7, 28, 14, 14);

  IngestResult saved({
    String id = 'tx-1',
    String? categoryId,
    TxDirection direction = TxDirection.debit,
    IngestStatus status = IngestStatus.saved,
    Duration age = const Duration(minutes: 1),
    DateTime? at,
    String? merchant = 'Mr Price',
    int amountMinor = 8500,
  }) => IngestResult(
    status,
    transaction: Transaction(
      id: id,
      accountId: 'acc',
      categoryId: categoryId,
      amountMinor: amountMinor,
      currency: 'ZMW',
      direction: direction,
      merchant: merchant,
      transactedAt: at ?? now.subtract(age),
      source: TxSource.sms,
      status: TxStatus.confirmed,
      idempotencyKey: 'key-$id',
    ),
  );

  group('NudgePolicy.isEligible', () {
    test('accepts a fresh uncategorized debit', () {
      expect(NudgePolicy.isEligible(saved(), now), isTrue);
    });

    test('ignores a transaction the categorizer already placed', () {
      expect(NudgePolicy.isEligible(saved(categoryId: 'food'), now), isFalse);
    });

    test('ignores money received', () {
      expect(
        NudgePolicy.isEligible(saved(direction: TxDirection.credit), now),
        isFalse,
      );
    });

    test('ignores anything that was not newly saved', () {
      for (final status in IngestStatus.values) {
        if (status == IngestStatus.saved) continue;
        expect(
          NudgePolicy.isEligible(saved(status: status), now),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('ignores a capture too old for the user to remember', () {
      expect(
        NudgePolicy.isEligible(saved(age: const Duration(hours: 3)), now),
        isFalse,
      );
    });

    test('ignores a result with no transaction', () {
      expect(
        NudgePolicy.isEligible(const IngestResult(IngestStatus.saved), now),
        isFalse,
      );
    });
  });

  group('NudgeSettings.isQuiet', () {
    test('wraps past midnight by default', () {
      const settings = NudgeSettings();
      expect(settings.isQuiet(DateTime(2026, 7, 28, 23)), isTrue);
      expect(settings.isQuiet(DateTime(2026, 7, 28, 3)), isTrue);
      expect(settings.isQuiet(DateTime(2026, 7, 28, 7)), isFalse);
      expect(settings.isQuiet(DateTime(2026, 7, 28, 21, 59)), isFalse);
    });

    test('handles a same-day window', () {
      const settings = NudgeSettings(quietStartHour: 13, quietEndHour: 15);
      expect(settings.isQuiet(DateTime(2026, 7, 28, 13)), isTrue);
      expect(settings.isQuiet(DateTime(2026, 7, 28, 15)), isFalse);
    });

    test('equal hours mean no quiet window', () {
      const settings = NudgeSettings(quietStartHour: 9, quietEndHour: 9);
      expect(settings.isQuiet(DateTime(2026, 7, 28, 9)), isFalse);
    });

    test('shows the floating card unless the user turned it off', () {
      expect(const NudgeSettings().overlay, isTrue);
      expect(NudgeSettings.fromJson(const {}).overlay, isTrue);
      expect(NudgeSettings.fromJson(const {'overlay': false}).overlay, isFalse);
    });

    test('is on unless the user turned it off', () {
      expect(const NudgeSettings().enabled, isTrue);
      expect(NudgeSettings.fromJson(const {}).enabled, isTrue);
      expect(NudgeSettings.fromJson(const {'enabled': false}).enabled, isFalse);
    });

    test('round-trips through JSON and survives bad values', () {
      const settings = NudgeSettings(enabled: true, quietStartHour: 21);
      expect(NudgeSettings.fromJson(settings.toJson()), settings);
      expect(
        NudgeSettings.fromJson({'enabled': true, 'quietStartHour': 99}),
        const NudgeSettings(enabled: true),
      );
    });
  });

  group('BatchingCaptureNudger', () {
    late AppServices services;
    late _RecordingNotifier notifier;
    late BatchingCaptureNudger nudger;
    var clock = now;

    setUp(() async {
      services = await createTestServices();
      notifier = _RecordingNotifier();
      clock = now;
      nudger = BatchingCaptureNudger(
        settings: services.nudgeSettings,
        notifier: notifier,
        clock: () => clock,
      );
    });

    tearDown(() async {
      await nudger.dispose();
      await services.dispose();
    });

    Future<void> enable() =>
        services.nudgeSettings.save(const NudgeSettings(enabled: true));

    test('stays silent when the user has switched it off', () async {
      await services.nudgeSettings.save(const NudgeSettings(enabled: false));
      await nudger.onIngest(saved());
      await nudger.flush();

      expect(notifier.shown, isEmpty);
    });

    test('asks about a single uncategorized debit', () async {
      await enable();

      await nudger.onIngest(saved());
      await nudger.flush();

      expect(notifier.shown, hasLength(1));
      final message = notifier.shown.single;
      expect(message.title, 'What was this?');
      expect(message.body, contains('K85.00'));
      expect(message.body, contains('Mr Price'));
      expect(message.link.toString(), 'intellispendiq://transaction/tx-1');
    });

    test('omits the merchant when there is none', () async {
      await enable();

      await nudger.onIngest(saved(merchant: null));
      await nudger.flush();

      expect(notifier.shown.single.body, startsWith('K85.00 · '));
      expect(notifier.shown.single.body.split(' · '), hasLength(2));
    });

    test('folds a burst into one notification', () async {
      await enable();

      await nudger.onIngest(saved(id: 'a'));
      await nudger.onIngest(saved(id: 'b'));
      await nudger.onIngest(saved(id: 'c'));
      await nudger.flush();

      expect(notifier.shown, hasLength(1));
      final message = notifier.shown.single;
      expect(message.title, '3 new transactions need a category');
      expect(message.id, BatchingCaptureNudger.batchNotificationId);
      expect(message.link.toString(), 'intellispendiq://review');
    });

    test('does not repeat itself after a flush', () async {
      await enable();

      await nudger.onIngest(saved());
      await nudger.flush();
      await nudger.flush();

      expect(notifier.shown, hasLength(1));
    });

    test('holds back during quiet hours', () async {
      await enable();
      clock = DateTime(2026, 7, 28, 23, 14);

      await nudger.onIngest(saved(at: clock));
      await nudger.flush();

      expect(notifier.shown, isEmpty);
    });

    test('offers the suggested categories on a single nudge', () async {
      await enable();
      nudger = BatchingCaptureNudger(
        settings: services.nudgeSettings,
        notifier: notifier,
        clock: () => clock,
        suggestions: () async => const [
          NudgeAction(categoryId: 'food', label: 'Food'),
          NudgeAction(categoryId: 'transport', label: 'Transport'),
        ],
      );

      await nudger.onIngest(saved());
      await nudger.flush();

      expect(notifier.shown.single.actions.map((a) => a.id), [
        'cat:food',
        'cat:transport',
      ]);
    });

    test('still nudges when suggestions fail', () async {
      await enable();
      nudger = BatchingCaptureNudger(
        settings: services.nudgeSettings,
        notifier: notifier,
        clock: () => clock,
        suggestions: () async => throw StateError('no history yet'),
      );

      await nudger.onIngest(saved());
      await nudger.flush();

      expect(notifier.shown, hasLength(1));
      expect(notifier.shown.single.actions, isEmpty);
    });

    test('offers no buttons on a batched nudge', () async {
      await enable();
      nudger = BatchingCaptureNudger(
        settings: services.nudgeSettings,
        notifier: notifier,
        clock: () => clock,
        suggestions: () async => const [
          NudgeAction(categoryId: 'food', label: 'Food'),
        ],
      );

      await nudger.onIngest(saved(id: 'a'));
      await nudger.onIngest(saved(id: 'b'));
      await nudger.flush();

      expect(notifier.shown.single.actions, isEmpty);
    });

    test('lists every category for the floating card', () async {
      await enable();
      nudger = BatchingCaptureNudger(
        settings: services.nudgeSettings,
        notifier: notifier,
        clock: () => clock,
        categoryOptions: () async => const [
          NudgeAction(categoryId: 'food', label: 'Food'),
          NudgeAction(categoryId: 'rent', label: 'Rent'),
        ],
      );

      await nudger.onIngest(saved());
      await nudger.flush();

      final message = notifier.shown.single;
      expect(message.transactionId, 'tx-1');
      expect(message.options.map((o) => o.categoryId), ['food', 'rent']);
    });

    test('leaves the card out when the user switched it off', () async {
      await services.nudgeSettings.save(const NudgeSettings(overlay: false));
      nudger = BatchingCaptureNudger(
        settings: services.nudgeSettings,
        notifier: notifier,
        clock: () => clock,
        categoryOptions: () async => const [
          NudgeAction(categoryId: 'food', label: 'Food'),
        ],
      );

      await nudger.onIngest(saved());
      await nudger.flush();

      expect(notifier.shown.single.options, isEmpty);
      expect(notifier.shown.single.transactionId, 'tx-1');
    });

    test('has no transaction to file on a batched nudge', () async {
      await enable();

      await nudger.onIngest(saved(id: 'a'));
      await nudger.onIngest(saved(id: 'b'));
      await nudger.flush();

      expect(notifier.shown.single.transactionId, isNull);
      expect(notifier.shown.single.options, isEmpty);
    });

    test('ignores ineligible captures', () async {
      await enable();

      await nudger.onIngest(saved(categoryId: 'food'));
      await nudger.onIngest(saved(direction: TxDirection.credit));
      await nudger.flush();

      expect(notifier.shown, isEmpty);
    });
  });
  group('NudgeAction', () {
    test('round-trips a category id through the action id', () {
      const action = NudgeAction(categoryId: 'c-1', label: 'Food');

      expect(NudgeAction.categoryIdOf(action.id), 'c-1');
    });

    test('ignores action ids that are not category buttons', () {
      expect(NudgeAction.categoryIdOf(null), isNull);
      expect(NudgeAction.categoryIdOf('snooze_1h'), isNull);
      expect(NudgeAction.categoryIdOf('cat:'), isNull);
    });

    test('reads the transaction a payload points at', () {
      expect(
        NudgeAction.transactionIdOf('intellispendiq://transaction/tx-9'),
        'tx-9',
      );
      expect(NudgeAction.transactionIdOf('intellispendiq://review'), isNull);
      expect(NudgeAction.transactionIdOf(null), isNull);
    });
  });
}
