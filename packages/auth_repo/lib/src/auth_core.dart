import 'dart:async';
import 'dart:developer';

import 'package:auth_repo/auth_repo.dart';
import 'package:auth_repo/src/constants.dart';
import 'package:auth_repo/src/models/models.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';

/// Core authentication operations
class AuthCore {
  AuthCore(this._net, this._prefs, this._db, this._controller);

  final NetSource _net;
  final SharedPrefs _prefs;
  final LocalData _db;
  final StreamController<AuthStatus> _controller;

  static const String _keyId = AuthConstants.keyId;
  static const String _keyToken = AuthConstants.keyToken;
  static const String _keyLoggedIn = AuthConstants.keyLoggedIn;
  static const String _tblUsers = AuthConstants.tblUsers;

  Future<void> _initNetworkApi({String? token, String? refreshToken}) async {
    token ??= await _prefs.getString(_keyToken);
    refreshToken ??= await _prefs.getString(AuthConstants.keyCurrentToken);
    final deviceId = await _prefs.getString(AuthConstants.keyDeviceId);
    final appId = await _prefs.getString(AuthConstants.keyAppId);
    _net.init(
      deviceId: deviceId,
      appId: appId,
      token: token,
      refreshToken: refreshToken,
    );
  }

  /// User Registration
  Future<OpStatus> signup(JsonMap body) async {
    try {
      final response = await _net.post('registration', body);
      if (response.isSuccessful()) {
        await _getAndAuthUser(response);
      }
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in registration: $e');
      _controller.add(AuthStatus.unauthenticated);
      return OpStatus.unexpected(e.toString());
    }
  }

  /// User Login
  Future<OpStatus> login(JsonMap body) async {
    try {
      final response = await _net.post('login', body);
      if (response.isSuccessful()) {
        await _getAndAuthUser(response);
      }
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in login: $e');
      _controller.add(AuthStatus.unauthenticated);
      return OpStatus.unexpected(e.toString());
    }
  }

  /// Function to logout
  Future<void> logOut() async {
    await _prefs.deleteValue(_keyId);
    await _prefs.deleteValue(_keyLoggedIn);
    await _db.deleteAll(_tblUsers);
    await _prefs.deleteValue(_keyToken);
    _controller.add(AuthStatus.unauthenticated);
  }

  Future<void> _getAndAuthUser(NetResponse response) async {
    final responseData = response.data as JsonMap;
    final accessToken = responseData['accessToken'] as String?;
    final refreshToken = responseData['refreshToken'] as String?;
    await _prefs.set(_keyLoggedIn, true);
    await _prefs.set(_keyToken, accessToken);
    await _prefs.set(AuthConstants.keyCurrentToken, refreshToken);
    await _initNetworkApi(token: accessToken);
    final userMap = responseData['user'] as JsonMap;
    log('User map from API: $userMap');
    final user = User.fromJson(userMap);
    log('User after fromJson: $user');
    await _db.insertOne(_tblUsers, user.toJsonDb());
    await _prefs.set(_keyId, user.id);
    _controller.add(AuthStatus.authenticated);
  }
}
