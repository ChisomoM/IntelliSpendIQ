import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';
import 'package:intellispendiq/platform/overlay_nudge_notifier.dart';

class _RecordingNotifier implements NudgeNotifier {
  final shown = <NudgeMessage>[];

  @override
  Future<void> show(NudgeMessage message) async => shown.add(message);
}

class _ThrowingNotifier implements NudgeNotifier {
  @override
  Future<void> show(NudgeMessage message) async =>
      throw StateError('this one is broken');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/overlay');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  NudgeMessage message({
    String? transactionId = 'tx-1',
    List<NudgeAction> options = const [
      NudgeAction(categoryId: 'food', label: 'Food'),
      NudgeAction(categoryId: 'fun', label: 'Fun'),
    ],
  }) => NudgeMessage(
    id: 42,
    title: 'What was this?',
    body: 'K85.00 · Mr Price · 1:14 PM',
    link: Uri.parse('intellispendiq://transaction/tx-1'),
    actions: const [NudgeAction(categoryId: 'food', label: 'Food')],
    transactionId: transactionId,
    options: options,
  );

  group('OverlayNudgeNotifier', () {
    test('hands native the words and the choices', () async {
      await OverlayNudgeNotifier(channel: channel).show(message());

      expect(calls, hasLength(1));
      expect(calls.single.method, 'showOverlay');
      expect(calls.single.arguments, {
        'transactionId': 'tx-1',
        'notificationId': 42,
        'title': 'What was this?',
        'body': 'K85.00 · Mr Price · 1:14 PM',
        'suggestions': [
          {'id': 'food', 'label': 'Food'},
        ],
        'options': [
          {'id': 'food', 'label': 'Food'},
          {'id': 'fun', 'label': 'Fun'},
        ],
      });
    });

    test('shows nothing for a batched nudge', () async {
      await OverlayNudgeNotifier(
        channel: channel,
      ).show(message(transactionId: null));

      expect(calls, isEmpty);
    });

    test('shows nothing when the card is switched off', () async {
      await OverlayNudgeNotifier(
        channel: channel,
      ).show(message(options: const []));

      expect(calls, isEmpty);
    });

    test('stays out of the way while suppressed', () async {
      await OverlayNudgeNotifier(
        channel: channel,
        isSuppressed: () => true,
      ).show(message());

      expect(calls, isEmpty);
    });
  });

  group('CompositeNudgeNotifier', () {
    test('shows through every notifier', () async {
      final first = _RecordingNotifier();
      final second = _RecordingNotifier();

      await CompositeNudgeNotifier([first, second]).show(message());

      expect(first.shown, hasLength(1));
      expect(second.shown, hasLength(1));
    });

    test('one failing does not stop the others', () async {
      final after = _RecordingNotifier();

      await CompositeNudgeNotifier([
        _ThrowingNotifier(),
        after,
      ]).show(message());

      expect(after.shown, hasLength(1));
    });
  });
}
