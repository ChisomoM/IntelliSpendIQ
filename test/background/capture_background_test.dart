import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/background/capture_background.dart';
import 'package:intellispendiq/background/nudge_actions.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/fee_schedule_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/nudge_settings.dart';
import 'package:intellispendiq/domain/services/capture_core.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';

import '../support/corpus.dart';

class _RecordingNotifier implements NudgeNotifier {
  final shown = <NudgeMessage>[];

  @override
  Future<void> show(NudgeMessage message) async => shown.add(message);
}

void main() {
  late CaptureCore core;
  late _RecordingNotifier notifier;
  late BackgroundCaptureHandler handler;

  setUp(() async {
    notifier = _RecordingNotifier();
    core = await CaptureCore.create(
      db: AppDatabase(NativeDatabase.memory()),
      userId: 'test-user',
      fees: MemoryFeeScheduleRepository(),
      nudgeNotifier: notifier,
    );
    // No quiet window, so the result does not depend on the hour the
    // tests happen to run at.
    await core.nudgeSettings.save(
      const NudgeSettings(enabled: true, quietStartHour: 0, quietEndHour: 0),
    );
    handler = BackgroundCaptureHandler(openCore: () async => core);
  });

  tearDown(() => core.dispose());

  Map<Object?, Object?> sms(
    String body, {
    String address = Corpus.airtelSender,
    DateTime? at,
  }) => {
    'channel': 'sms',
    'id': null,
    'address': address,
    'body': body,
    'date': (at ?? DateTime.now().subtract(const Duration(minutes: 1)))
        .millisecondsSinceEpoch,
  };

  group('BackgroundCaptureHandler', () {
    test('saves a message from a known sender and nudges', () async {
      final status = await handler.ingest(sms(Corpus.paymentTillNamed));

      expect(status, 'saved');
      final saved = await core.transactions.watchRecent().first;
      expect(saved, hasLength(1));
      expect(saved.single.categoryId, isNull);
      expect(notifier.shown, hasLength(1));
      expect(notifier.shown.single.title, 'What was this?');
      expect(
        notifier.shown.single.link.toString(),
        'intellispendiq://transaction/${saved.single.id}',
      );
    });

    test('stays silent when the nudge setting is off', () async {
      await core.nudgeSettings.save(const NudgeSettings());

      final status = await handler.ingest(sms(Corpus.paymentTillNamed));

      expect(status, 'saved');
      expect(notifier.shown, isEmpty);
    });

    test('does not store a message from an unknown sender', () async {
      final status = await handler.ingest(
        sms('Hi, are we still on for lunch?', address: '0977123456'),
      );

      expect(status, 'unknownSender');
      expect(await core.db.select(core.db.rawCaptures).get(), isEmpty);
      expect(notifier.shown, isEmpty);
    });

    test('a repeated delivery saves and nudges once', () async {
      final payload = sms(Corpus.paymentTillNamed);

      expect(await handler.ingest(payload), 'saved');
      expect(await handler.ingest(payload), 'skippedExisting');

      expect(await core.transactions.watchRecent().first, hasLength(1));
      expect(notifier.shown, hasLength(1));
    });

    test('reports an error instead of throwing', () async {
      final failing = BackgroundCaptureHandler(
        openCore: () async => throw StateError('cannot open the database'),
      );

      expect(await failing.ingest(sms(Corpus.paymentTillNamed)), 'error');
    });
  });

  group('handleNudgeAction', () {
    NotificationResponse tap({String? actionId, String? payload}) =>
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: actionId,
          payload: payload,
        );

    test('files the transaction under the tapped category', () async {
      await core.categories.ensureSeeds();
      final food = (await core.categories.byName('Food'))!;
      await handler.ingest(sms(Corpus.paymentTillNamed));
      final transaction = (await core.transactions.watchRecent().first).single;

      final handled = await handleNudgeAction(
        tap(
          actionId: NudgeAction(categoryId: food.id, label: 'Food').id,
          payload: notifier.shown.single.link.toString(),
        ),
        openCore: () async => core,
      );

      expect(handled, isTrue);
      final updated = (await core.transactions.byId(transaction.id))!;
      expect(updated.categoryId, food.id);
      expect(updated.status, TxStatus.confirmed);
    });

    test('leaves actions that are not ours alone', () async {
      expect(
        await handleNudgeAction(
          tap(actionId: 'snooze_1h'),
          openCore: () async => core,
        ),
        isFalse,
      );
      expect(
        await handleNudgeAction(
          tap(actionId: 'cat:abc', payload: 'not a link'),
          openCore: () async => core,
        ),
        isFalse,
      );
    });
  });
}
