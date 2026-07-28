import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';
import 'package:notifications_repo/src/models/models.dart';
import 'package:permission_client/permission_client.dart';

/// {@template notifications_repo}
/// Repository responsible for notifications
/// {@endtemplate}
class NotificationsRepo {
  /// {@macro notifications_repo}
  NotificationsRepo({
    required SharedPrefs prefs,
    // required SocketSource socket,
    required PermissionClient permissionClient,
    required NetSource net,
  })  : _prefs = prefs,
        // _socket = socket,
        _permissionClient = permissionClient,
        _net = net;

  // Shared preferences keys
  final String _keyLastNotification = 'last_notification';
  final String _keyNotificationEnabled = 'notification_enabled';

  final SharedPrefs _prefs;
  // final SocketSource _socket;
  final PermissionClient _permissionClient;
  final NetSource _net;

  final _controller = StreamController<JsonMap>.broadcast();

  /// Stream of [JsonMap] which will emit the current user when
  /// the authentication state changes.
  Stream<JsonMap> get notification async* {
    yield* _controller.stream;
  }

  /// Returns the last notification in [JsonMap] object or null.
  Future<JsonMap?> getLastNotification() async {
    final stringData = await _prefs.getString(_keyLastNotification);
    if (stringData == null) return null;
    final notificationData = jsonDecode(stringData);
    return notificationData as JsonMap?;
  }

  /// Get the latest app update details
  Future<UpdateDetails?> checkUpdate(String platform) async {
    try {
      final response = await _net.get('Auth/GetAppUpdates?name=$platform');
      if (response.isSuccessful()) {
        return UpdateDetails.fromJson(
          UpdateDetails.filter(response.data as JsonMap),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Toggles the notifications based on the [enable].
  ///
  /// When [enable] is true, request the notification permission if not granted
  /// and marks the notification setting as enabled. Subscribes the user to
  /// notifications related to user's categories preferences.
  ///
  /// When [enable] is false, marks notification setting as disabled and
  /// unsubscribes the user from notifications related to user's categories
  /// preferences.
  Future<void> toggleNotifications({required bool enable}) async {
    try {
      // Request the notification permission when turning notifications on.
      if (enable) {
        // Find the current notification permission status.
        final permissionStatus = await _permissionClient.notificationsStatus();

        // Navigate the user to permission settings
        // if the permission status is permanently denied or restricted.
        if (permissionStatus.isPermanentlyDenied ||
            permissionStatus.isRestricted) {
          await _permissionClient.openPermissionSettings();
          return;
        }

        // Request the permission if the permission status is denied.
        if (permissionStatus.isDenied) {
          final updatedPermissionStatus =
              await _permissionClient.requestNotifications();
          if (!updatedPermissionStatus.isGranted) {
            return;
          }
        }
      }

      // Update the notifications enabled in Storage.
      await _prefs.set(_keyNotificationEnabled, enable);
    } catch (error, stackTrace) {
      log('$error');
      log('$stackTrace');
    }
  }
}
