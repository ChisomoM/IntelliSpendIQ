import 'dart:async';

import 'package:intellispendiq/data/repositories/settings_repository.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';

/// Feeds the capture pipeline from the device:
/// - a launch-time inbox diff (the source of truth — OEMs drop
///   broadcasts, plan risk #10), filtered to known senders;
/// - live SMS / notification events while the app runs.
class SmsSyncService {
  SmsSyncService({
    required CaptureBridge bridge,
    required CaptureService captureService,
    required ParserRegistry registry,
    required SettingsRepository settings,
  }) : _bridge = bridge,
       _captureService = captureService,
       _registry = registry,
       _settings = settings;

  static const backfillWindow = Duration(days: 30);

  final CaptureBridge _bridge;
  final CaptureService _captureService;
  final ParserRegistry _registry;
  final SettingsRepository _settings;

  StreamSubscription<CaptureInput>? _eventSubscription;

  /// Reads the inbox since the stored watermark (first run: last 30
  /// days, plan §7.4) and ingests messages from known senders only.
  /// Returns how many messages were ingested (not skipped).
  Future<int> backfill() async {
    if (!await _bridge.hasSmsPermission()) return 0;
    final watermark = await _settings.getInt(
      SettingsRepository.smsBackfillWatermarkKey,
    );
    final since =
        watermark ??
        DateTime.now().subtract(backfillWindow).millisecondsSinceEpoch;

    final messages = await _bridge.readInboxSince(since);
    var ingested = 0;
    var newest = since;
    for (final message in messages) {
      final receivedMs = message.receivedAt.millisecondsSinceEpoch;
      if (receivedMs > newest) newest = receivedMs;
      // Backfill only known provider senders — a full inbox import
      // would flood raw_captures with personal messages.
      if (!_registry.isKnownSender(message.sender)) continue;
      final result = await _captureService.ingest(message);
      if (result.status != IngestStatus.skippedExisting) ingested++;
    }
    await _settings.set(
      SettingsRepository.smsBackfillWatermarkKey,
      newest.toString(),
    );
    return ingested;
  }

  /// Starts listening to live capture events. Every event goes through
  /// the same ingest pipeline as the backfill (idempotent by content
  /// hash / SMS id, so overlap with backfill is harmless).
  void startListening({void Function(IngestResult result)? onIngest}) {
    _eventSubscription ??= _bridge.events().listen((input) async {
      final result = await _captureService.ingest(input);
      onIngest?.call(result);
    });
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
