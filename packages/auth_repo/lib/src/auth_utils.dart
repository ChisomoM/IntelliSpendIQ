import 'dart:async';
import 'dart:developer';

import 'package:auth_repo/src/constants.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
// import 'package:shared_preferences/shared_preferences.dart';

/// Authentication utilities
class AuthUtils {
  AuthUtils(this._net, this._prefs, this._isDev, this._themeController);

  final NetSource _net;
  final SharedPrefs _prefs;
  final bool _isDev;
  final StreamController<int> _themeController;

  static const String _keyAppVersion = AuthConstants.keyAppVersion;
  static const String _keyTheme = AuthConstants.keyTheme;
  static const String _keyDeviceId = AuthConstants.keyDeviceId;
  static const String _keyAppId = AuthConstants.keyAppId;

  /// Returns the device id used for network requests.
  Future<String?> getDeviceId() async {
    const uuid = Uuid();
    var deviceId = await _prefs.getString(_keyDeviceId);
    var appId = await _prefs.getString(_keyAppId);
    if (deviceId == null) {
      deviceId = uuid.v4();
      await _prefs.set(_keyDeviceId, deviceId);
    }
    appId ??= '1efc7d35-7fd0-6000-a000-0123456789ab';
    await _prefs.set(_keyAppId, appId);
    return deviceId;
  }

  /// Save app version into shared preferences
  Future<void> _saveAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    var isDev = 'Dev';
    if (!_isDev) isDev = '';
    await _prefs.set(
      _keyAppVersion,
      '${info.version}:${info.buildNumber}-$isDev',
    );
  }

  /// Get the app theme
  Future<int> getTheme() async {
    return await _prefs.getInt(_keyTheme, defaultValue: 0) ?? 0;
  }

  /// Set the app theme
  Future<void> setTheme(int themeMode) async {
    await _prefs.set(_keyTheme, themeMode);
    _themeController.add(themeMode);
  }

  /// Gets the current app version.
  Future<String?> getAppVersion() async {
    await _saveAppVersion();
    return _prefs.getString(_keyAppVersion);
  }

  /// Add this method to your AuthRepo class
  Future<NetResponse> uploadFile(
    String endpoint,
    Map<String, dynamic> formData,
  ) async {
    try {
      return await _net.uploadFile(endpoint, formData);
    } catch (e) {
      log('Error uploading file: $e');
      return NetResponse(message: e.toString(), status: 2);
    }
  }

  /// Get the app theme stream
  Stream<int> get theme async* {
    final appTheme = await _prefs.getInt(_keyTheme, defaultValue: 0) ?? 0;
    yield appTheme;
    yield* _themeController.stream;
  }
}
