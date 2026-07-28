import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';

import '../../support/corpus.dart';
import '../../support/test_harness.dart';

/// Stands in for the Android bridge so the backfill and live-event paths
/// can be exercised without a device.
class _FakeBridge implements CaptureBridge {
  _FakeBridge({this.inbox = const [], this.permission = true});

  final List<CaptureInput> inbox;
  final bool permission;
  final _events = StreamController<CaptureInput>.broadcast();
  final readCalls = <int>[];

  @override
  Future<bool> hasSmsPermission() async => permission;

  @override
  Future<bool> requestSmsPermission() async => permission;

  @override
  Future<bool> isNotificationAccessGranted() async => false;

  @override
  Future<void> requestNotificationAccess() async {}

  @override
  Future<List<CaptureInput>> readInboxSince(int sinceMs) async {
    readCalls.add(sinceMs);
    return inbox
        .where((m) => m.receivedAt.millisecondsSinceEpoch >= sinceMs)
        .toList();
  }

  @override
  Stream<CaptureInput> events() => _events.stream;

  void emit(CaptureInput input) => _events.add(input);

  Future<void> close() => _events.close();
}

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  SmsSyncService syncWith(_FakeBridge bridge) => SmsSyncService(
    bridge: bridge,
    captureService: services.captureService,
    registry: ParserRegistry(),
    settings: services.settings,
  );

  group('backfill', () {
    test('ingests provider messages and ignores personal ones', () async {
      final bridge = _FakeBridge(
        inbox: [
          Corpus.capture(Corpus.withdrawal, androidSmsId: '1'),
          Corpus.capture(
            'Lunch tomorrow?',
            sender: 'Mum',
            androidSmsId: '2',
          ),
          Corpus.capture(
            Corpus.stanChartTransfer,
            sender: Corpus.stanChartSender,
            androidSmsId: '3',
          ),
        ],
      );
      addTearDown(bridge.close);

      final ingested = await syncWith(bridge).backfill();

      expect(ingested, 2, reason: 'Only the two provider messages');
      final rows = await services.transactions.watchRecent().first;
      expect(rows, hasLength(2));

      // The personal message is never even stored — a full inbox import
      // would flood raw_captures with private conversations.
      final captures = await services.rawCaptures.countByParseStatus();
      expect(captures.values.fold(0, (a, b) => a + b), 2);
    });

    test('does nothing when SMS permission has not been granted', () async {
      final bridge = _FakeBridge(
        inbox: [Corpus.capture(Corpus.withdrawal)],
        permission: false,
      );
      addTearDown(bridge.close);

      expect(await syncWith(bridge).backfill(), 0);
      expect(await services.transactions.watchRecent().first, isEmpty);
    });

    test('advances the watermark so the next run reads less', () async {
      final bridge = _FakeBridge(
        inbox: [
          Corpus.capture(
            Corpus.withdrawal,
            androidSmsId: '1',
            receivedAt: DateTime(2026, 7, 28, 9),
          ),
        ],
      );
      addTearDown(bridge.close);
      final sync = syncWith(bridge);

      await sync.backfill();
      final watermark = await services.settings.getInt(
        SettingsRepository.smsBackfillWatermarkKey,
      );
      expect(
        watermark,
        DateTime(2026, 7, 28, 9).millisecondsSinceEpoch,
      );

      await sync.backfill();
      expect(bridge.readCalls.last, watermark);
    });

    test('first run looks back 30 days, not to the start of time', () async {
      final bridge = _FakeBridge();
      addTearDown(bridge.close);

      await syncWith(bridge).backfill();

      final expected = DateTime.now()
          .subtract(SmsSyncService.backfillWindow)
          .millisecondsSinceEpoch;
      expect(
        (bridge.readCalls.single - expected).abs(),
        lessThan(const Duration(minutes: 1).inMilliseconds),
      );
    });

    test('re-running does not duplicate already-captured messages', () async {
      final bridge = _FakeBridge(
        inbox: [Corpus.capture(Corpus.withdrawal, androidSmsId: '1')],
      );
      addTearDown(bridge.close);
      final sync = syncWith(bridge);

      await sync.backfill();
      await sync.backfill();

      expect(await services.transactions.watchRecent().first, hasLength(1));
    });
  });

  group('live events', () {
    test('ingests an SMS that arrives while the app is open', () async {
      final bridge = _FakeBridge();
      addTearDown(bridge.close);
      final sync = syncWith(bridge);

      final ingested = Completer<void>();
      sync.startListening(onIngest: (_) => ingested.complete());
      bridge.emit(Corpus.capture(Corpus.paymentTillNamed));
      await ingested.future.timeout(const Duration(seconds: 2));

      final rows = await services.transactions.watchRecent().first;
      expect(rows, hasLength(1));
      expect(rows.single.amountMinor, 1000);
      await sync.dispose();
    });

    test('a live event and a backfill of the same SMS are not '
        'double-counted', () async {
      final message = Corpus.capture(Corpus.withdrawal, androidSmsId: '77');
      final bridge = _FakeBridge(inbox: [message]);
      addTearDown(bridge.close);
      final sync = syncWith(bridge);

      final ingested = Completer<void>();
      sync.startListening(onIngest: (_) => ingested.complete());
      bridge.emit(message);
      await ingested.future.timeout(const Duration(seconds: 2));
      await sync.backfill();

      expect(await services.transactions.watchRecent().first, hasLength(1));
      await sync.dispose();
    });
  });
}
