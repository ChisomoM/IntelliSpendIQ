import 'package:flutter/services.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Dart side of the native capture bridge (plan §7.3).
///
/// Native Android only captures and forwards `{id, address, body, date}`
/// payloads; all parsing stays in Dart so unit tests never need a device.
class CaptureBridge {
  CaptureBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods = methodChannel ?? const MethodChannel(methodChannelName),
       _events = eventChannel ?? const EventChannel(eventChannelName);

  static const methodChannelName = 'com.intellispendiq/capture';
  static const eventChannelName = 'com.intellispendiq/capture_events';

  final MethodChannel _methods;
  final EventChannel _events;

  Future<bool> hasSmsPermission() async =>
      await _methods.invokeMethod<bool>('hasSmsPermission') ?? false;

  Future<bool> requestSmsPermission() async =>
      await _methods.invokeMethod<bool>('requestSmsPermission') ?? false;

  /// Tells native which sender IDs the parsers recognize, so the SMS
  /// receiver can ignore everything else without starting the pipeline.
  /// [senders] must already be normalized (`ParserRegistry.knownSenderIds`).
  Future<void> setKnownSenders(Iterable<String> senders) => _methods
      .invokeMethod<void>('setKnownSenders', {'senders': senders.toList()});

  /// Whether Android lets the app run in the background without battery
  /// restrictions. The SMS receiver can still start the pipeline when it
  /// is not, but phone makers' battery managers are more likely to kill
  /// the work.
  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _methods.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
      false;

  /// Whether the "Display over other apps" permission is granted, which
  /// the floating category card needs.
  Future<bool> canDrawOverlays() async =>
      await _methods.invokeMethod<bool>('canDrawOverlays') ?? false;

  /// Opens the system screen where "Display over other apps" is granted.
  /// It cannot be requested with a dialog.
  Future<void> openOverlaySettings() =>
      _methods.invokeMethod<void>('openOverlaySettings');

  /// Opens this app's notification settings in the system, where the
  /// permission can be given back after it was denied (Android will not
  /// show its own prompt a second time).
  Future<void> openNotificationSettings() =>
      _methods.invokeMethod<void>('openNotificationSettings');

  /// Opens the system battery-optimization screen.
  Future<void> openBatterySettings() =>
      _methods.invokeMethod<void>('openBatterySettings');

  Future<bool> isNotificationAccessGranted() async =>
      await _methods.invokeMethod<bool>('isNotificationAccessGranted') ?? false;

  /// Opens the system Notification Access settings screen — access
  /// cannot be granted programmatically.
  Future<void> requestNotificationAccess() =>
      _methods.invokeMethod<void>('requestNotificationAccess');

  /// Reads the SMS inbox since [sinceMs] (epoch millis). Returns raw
  /// payloads for every message; filtering by sender happens in Dart.
  Future<List<CaptureInput>> readInboxSince(int sinceMs) async {
    final result = await _methods.invokeListMethod<Map<Object?, Object?>>(
      'readInboxSince',
      {'sinceMs': sinceMs},
    );
    return (result ?? []).map(_smsFromPayload).toList();
  }

  /// Live capture events (incoming SMS / notifications) while the app
  /// runs. Payloads carry a `channel` discriminator.
  Stream<CaptureInput> events() {
    return _events.receiveBroadcastStream().map((event) {
      return inputFromPayload((event as Map).cast<Object?, Object?>());
    });
  }

  /// Decodes one native capture payload — the shape the live event
  /// stream and the background (app closed) path both send.
  static CaptureInput inputFromPayload(Map<Object?, Object?> payload) {
    if (payload['channel'] == 'notification') {
      return CaptureInput(
        channel: CaptureChannel.notification,
        sender: payload['title'] as String?,
        packageName: payload['packageName'] as String?,
        body: payload['body']! as String,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          (payload['date']! as num).toInt(),
        ),
      );
    }
    return _smsFromPayload(payload);
  }

  static CaptureInput _smsFromPayload(Map<Object?, Object?> payload) {
    return CaptureInput(
      channel: CaptureChannel.smsInbox,
      sender: payload['address'] as String?,
      body: payload['body']! as String,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (payload['date']! as num).toInt(),
      ),
      androidSmsId: payload['id']?.toString(),
    );
  }
}
