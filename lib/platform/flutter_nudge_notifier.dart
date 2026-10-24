import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellispendiq/domain/services/capture_nudger.dart';

/// Posts nudges through the same notification plugin instance that
/// `ReminderScheduler` initializes, so a tap arrives through its
/// response handler and is routed as a deep link from the payload.
class FlutterNudgeNotifier implements NudgeNotifier {
  FlutterNudgeNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'capture_nudges';
  static const _channelName = 'Categorize prompts';
  static const _channelDescription =
      'Asks what a new transaction was while you still remember';

  @override
  Future<void> show(NudgeMessage message) {
    return _plugin.show(
      message.id,
      message.title,
      message.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          actions: [
            // No user interface: the tap is answered by a background
            // isolate (`handleNudgeAction`) and the notification clears,
            // so the whole job is one tap from the shade.
            for (final action in message.actions)
              AndroidNotificationAction(action.id, action.label),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.link.toString(),
    );
  }
}
