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
      final payload = (event as Map).cast<Object?, Object?>();
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
    });
  }

  CaptureInput _smsFromPayload(Map<Object?, Object?> payload) {
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
