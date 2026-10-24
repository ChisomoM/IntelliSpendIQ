import 'dart:developer';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellispendiq/domain/services/capture_core.dart';
import 'package:intellispendiq/platform/capture_bridge.dart';
import 'package:intellispendiq/platform/flutter_nudge_notifier.dart';

/// Channel between the native receiver and the headless engine it
/// starts. The engine calls `ready`; native answers by calling `ingest`
/// once with the message payload and tears the engine down when that
/// call returns.
const captureBackgroundChannelName = 'com.intellispendiq/capture_background';

/// Runs one captured message through the normal pipeline without any
/// UI: parse, dedupe, save, and nudge if it needs a category.
///
/// Opens the database lazily and holds it until [dispose], so a burst of
/// messages handled by one engine opens it once.
class BackgroundCaptureHandler {
  BackgroundCaptureHandler({required Future<CaptureCore> Function() openCore})
    : _openCore = openCore;

  final Future<CaptureCore> Function() _openCore;
  CaptureCore? _core;

  /// Ingests [payload] and returns the resulting `IngestStatus` name.
  ///
  /// Never throws: a failure is reported in the return value so native
  /// can finish the broadcast, and the message is still in the SMS
  /// inbox for the launch-time backfill (the source of truth).
  Future<String> ingest(Map<Object?, Object?> payload) async {
    try {
      final core = _core ??= await _openCore();
      final input = CaptureBridge.inputFromPayload(payload);
      // Native already filters by sender; this is the authority. Live
      // ingest in the running app keeps unknown senders as `ignored` raw
      // captures, but a background wake should never store a stranger's
      // message at all.
      if (!core.registry.isKnownSender(input.sender)) return 'unknownSender';
      final result = await core.captureService.ingest(input);
      await core.captureNudger.onIngest(result);
      await core.captureNudger.flush();
      return result.status.name;
    } on Object catch (error, stackTrace) {
      log(
        'Background capture failed',
        error: error,
        stackTrace: stackTrace,
        name: 'capture_background',
      );
      return 'error';
    }
  }

  Future<void> dispose() async {
    final core = _core;
    _core = null;
    await core?.dispose();
  }
}

/// Entrypoint the Android receiver runs in a headless Flutter engine
/// when an SMS arrives while the app is not running.
@pragma('vm:entry-point')
Future<void> captureBackgroundMain() async {
  DartPluginRegistrant.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  // Nothing taps a notification in this engine, but the plugin wants
  // initializing before it will post one. Taps are handled by the
  // app's own engine, which reads the payload on launch.
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final handler = BackgroundCaptureHandler(
    openCore: () =>
        CaptureCore.open(nudgeNotifier: FlutterNudgeNotifier(plugin: plugin)),
  );
  const channel = MethodChannel(captureBackgroundChannelName);
  channel.setMethodCallHandler((call) async {
    if (call.method != 'ingest') throw MissingPluginException();
    final payload = (call.arguments as Map).cast<Object?, Object?>();
    final status = await handler.ingest(payload);
    await handler.dispose();
    return status;
  });
  await channel.invokeMethod<void>('ready');
}
