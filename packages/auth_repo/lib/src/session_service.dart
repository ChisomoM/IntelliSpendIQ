import 'dart:async';
import 'dart:developer';

import 'package:auth_repo/auth_repo.dart';
import 'package:auth_repo/src/constants.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';
// import 'package:shared_preferences/shared_preferences.dart';

/// Session and token management operations
class SessionService {
  SessionService(this._net, this._prefs, this._controller);

  final NetSource _net;
  final SharedPrefs _prefs;
  final StreamController<AuthStatus> _controller;

  static const String _keyToken = AuthConstants.keyToken;
  static const String _keyCurrentToken = AuthConstants.keyCurrentToken;
  static const String _keyFCMToken = AuthConstants.keyFCMToken;

  /// Pipe function to check if token has been refreshed
  Future<dynamic> callService(Future<OpStatus?> Function() nextFunction) async {
    var response = await nextFunction.call();
    if (response?.code == 700) {
      log('Access Token Expired');
      final res = await refreshAccessToken();
      if (res.success) {
        final data = res.data as JsonMap;
        await _prefs.set(_keyToken, data['accessToken']);
        await _prefs.set(_keyCurrentToken, data['refreshToken']);
        response = await nextFunction.call();
      }
    }
    if (response?.code == 800) {
      log('Refresh Token Expired');
      _controller.add(AuthStatus.expired);
    }
    return response;
  }

  /// User Registration
  Future<OpStatus> refreshAccessToken() async {
    try {
      final refreshToken = await _prefs.getString(_keyCurrentToken);
      final response =
          await _net.post('refresh_token', {'refreshToken': refreshToken});
      if (response.isSuccessful()) {
        log('This is the RefreshToken Response: $response');
      } else {
        // await logOut(); // Would delegate to AuthCore
      }
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in registration: $e');
      _controller.add(AuthStatus.unauthenticated);
      return OpStatus.unexpected(e.toString());
    }
  }

  /// refreshes the session so a user is required to login before proceeding
  void refreshSession() => _controller.add(AuthStatus.expired);

  /// Save fcm token to shared prefs
  Future<void> setFcmToken(String fcmToken) async {
    log('FCM: $fcmToken');
    await _prefs.set(_keyFCMToken, fcmToken);
  }
}
