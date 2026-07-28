// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:auth_repo/src/auth_core.dart';
import 'package:auth_repo/src/auth_utils.dart';
import 'package:auth_repo/src/constants.dart';
import 'package:auth_repo/src/models/models.dart';
import 'package:auth_repo/src/session_service.dart';
import 'package:auth_repo/src/social_auth.dart';
import 'package:auth_repo/src/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Authentication statuses
enum AuthStatus {
  /// on startup, the authentication status of the user is unknown by default
  unknown,

  /// The status after a user is successfully authenticated
  authenticated,

  /// Refresh the current user data
  refresh,

  /// The status of a user after logging out or before logging in
  unauthenticated,

  /// The status of a user when his session has expired
  expired,

  /// The status o a guest user
  guest,
}

/// {@template auth_repo}
/// Repo for application authentication
/// {@endtemplate}
class AuthRepo {
  /// {@macro auth_repo}
  AuthRepo({
    required GoogleSignIn googleSignIn,
    required SignInWithApple signInWithApple,
    required fire_auth.FirebaseAuth auth,
    required bool isDev,
    required SharedPrefs prefs,
    required LocalData db,
    required NetSource net,
  })  : _prefs = prefs,
        _db = db,
        _net = net,
        _isDev = isDev,
        _auth = auth,
        _googleSignIn = googleSignIn,
        _signInWithApple = signInWithApple {
    _authCore = AuthCore(_net, _prefs, _db, _controller);
    _socialAuth = SocialAuth(_net, _auth, _googleSignIn);
    _userService = UserService(_net, _prefs, _db);
    _sessionService = SessionService(_net, _prefs, _controller);
    _authUtils = AuthUtils(_net, _prefs, _isDev, _themeController);

    _progressSub = _net.uploadProgress.listen(_progressController.add);
  }

  final SharedPrefs _prefs;
  final LocalData _db;
  final NetSource _net;
  final bool _isDev;
  final fire_auth.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final SignInWithApple _signInWithApple;

  late final AuthCore _authCore;
  late final SocialAuth _socialAuth;
  late final UserService _userService;
  late final SessionService _sessionService;
  late final AuthUtils _authUtils;

  late StreamSubscription<int> _progressSub;
  final _controller = StreamController<AuthStatus>.broadcast();
  final _progressController = StreamController<int>.broadcast();
  final _themeController = StreamController<int>.broadcast();

  /// Returns the device id used for network requests.
  Future<String?> getDeviceId() => _authUtils.getDeviceId();

  /// Pipe function to check if token has been refreshed
  Future<dynamic> callService(Future<OpStatus?> Function() nextFunction) =>
      _sessionService.callService(nextFunction);

  /// User Registration
  Future<OpStatus> signup(JsonMap body) => _authCore.signup(body);

  /// Logs in the user with a Google account.
  Future<OpStatus> continueWithGoogle([String type = 'login']) =>
      _socialAuth.continueWithGoogle(type);

  /// User Login
  Future<OpStatus> login(JsonMap body) => _authCore.login(body);

  /// Checking If User Has: Password, User Preferences and saving to Local DB.
  Future<OpStatus> fetchUserDetails(String? userId) =>
      _userService.fetchUserDetails(userId);

  // Edit User Profile
  Future<OpStatus> editUser(JsonMap body) => _userService.editUser(body);

  /// Add this method to your AuthRepo class
  Future<NetResponse> uploadFile(
    String endpoint,
    Map<String, dynamic> formData,
  ) =>
      _authUtils.uploadFile(endpoint, formData);

  /// Change Password
  Future<OpStatus> changePassword(JsonMap body) =>
      _userService.changePassword(body);

  // Forgot Password Start
  Future<OpStatus> forgotPassword(String email) =>
      _userService.forgotPassword(email);

  Future<OpStatus> verifyResetCode(String email, String code) =>
      _userService.verifyResetCode(email, code);

  Future<OpStatus> resetPassword(
    String code,
    String email,
    String newPassword,
  ) =>
      _userService.resetPassword(code, email, newPassword);

  /// Function to logout
  Future<void> logOut() => _authCore.logOut();

  /// Returns the logged in [User] object or null.
  Future<User?> getUser() => _userService.getUser();

  /// Returns the logged in [UserDetails] object or null.
  Future<UserDetails?> getUserDetails() => _userService.getUserDetails();

  /// Save app version into shared preferences
  Future<String?> getAppVersion() => _authUtils.getAppVersion();

  /// Get the app theme
  Future<int> getTheme() => _authUtils.getTheme();

  /// Set the app theme
  Future<void> setTheme(int themeMode) => _authUtils.setTheme(themeMode);

  /// Save fcm token to shared prefs
  Future<void> setFcmToken(String fcmToken) =>
      _sessionService.setFcmToken(fcmToken);

  /// refreshes the session so a user is required to login before proceeding
  void refreshSession() => _sessionService.refreshSession();

  /// User Registration
  Future<OpStatus> refreshAccessToken() => _sessionService.refreshAccessToken();

  ///
  Stream<AuthStatus> get status async* {
    await getDeviceId();
    final token = await _prefs.getString(AuthConstants.keyToken);
    final isLoggedIn = token != null;
    if (isLoggedIn) {
      yield AuthStatus.authenticated;
    } else {
      await logOut();
      yield AuthStatus.unauthenticated;
    }
    yield* _controller.stream;
  }

  /// The progress of an upload
  Stream<int> get uploadProgress async* {
    yield 0;
    yield* _progressController.stream;
  }

  /// Get the app theme stream
  Stream<int> get theme => _authUtils.theme;

  /// Closes the streams and cancels the subscriptions.
  void dispose() {
    _controller.close();
    _progressController.close();
    _themeController.close();
    _progressSub.cancel();
  }
}
