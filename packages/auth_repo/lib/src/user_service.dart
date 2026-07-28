import 'dart:developer';

import 'package:auth_repo/src/constants.dart';
import 'package:auth_repo/src/models/models.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';

/// User management operations
class UserService {
  UserService(this._net, this._prefs, this._db);

  final NetSource _net;
  final SharedPrefs _prefs;
  final LocalData _db;

  static const String _keyId = AuthConstants.keyId;
  static const String _tblUsers = AuthConstants.tblUsers;
  static const String _tblUserDetails = AuthConstants.tblUserDetails;

  /// Returns the logged in [User] object or null.
  Future<User?> getUser() async {
    final id = await _prefs.getString(_keyId);
    if (id == null) return null;
    final userData = await _db.getOne(_tblUsers, id);
    if (userData == null) return null;
    return User.fromDbJson(userData);
  }

  /// Returns the logged in [UserDetails] object or null.
  Future<UserDetails?> getUserDetails() async {
    final id = await _prefs.getString(_keyId);
    if (id == null) return null;
    final userData = await _db.getOne(_tblUserDetails, id);
    if (userData == null) return null;
    return UserDetails.fromDbJson(userData);
  }

  /// Checking If User Has: Password, User Preferences and saving to Local DB.
  Future<OpStatus> fetchUserDetails(String? userId) async {
    if (userId == null) return OpStatus.error('User ID is null');
    try {
      final response = await _net.get('user/$userId');
      if (response.isSuccessful()) {
        final responseData = response.data as Map<String, dynamic>;
        responseData['id'] = userId;
        final userDetails = UserDetails.fromJson(responseData);
        await _db.insertOne(_tblUserDetails, userDetails.toJsonDb());
      }
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in fetchUserDetails: $e');
      return OpStatus.unexpected(e.toString());
    }
  }

  // Edit User Profile
  Future<OpStatus> editUser(JsonMap body) async {
    final userId = await _prefs.getString(_keyId);
    try {
      final response = await _net.put('users/$userId', body);
      if (response.isSuccessful()) {
        final responseData = response.data as JsonMap;
        final data = <String, dynamic>{
          'id': userId,
          'avatar': responseData['avatar'],
          'name': responseData['name'],
          'email': responseData['email'],
          'phone': responseData['phone'],
          'accountType': responseData['accountType'],
          'updatedAt': responseData['updatedAt'],
          'isGmailIdUser': responseData['isGmailIdUser'] ?? 0,
          'isAppleIdUser': responseData['isAppleIdUser'] ?? 0,
          'createdAt': responseData['createdAt'],
          'deletedAt': responseData['deletedAt'],
        };
        await _db.updateOne(_tblUsers, data);
      }
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in editing: $e');
      return OpStatus.unexpected(e.toString());
    }
  }

  /// Change Password
  Future<OpStatus> changePassword(JsonMap body) async {
    final response = await _net.post('change-password', body);
    return OpStatus.fromResponse(response);
  }

  // Forgot Password Start
  Future<OpStatus> forgotPassword(String email) async {
    try {
      final response = await _net.post('forgot-password', {'email': email});
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in forgot password: $e');
      return OpStatus.unexpected(e.toString());
    }
  }

  Future<OpStatus> verifyResetCode(String email, String code) async {
    try {
      final response = await _net
          .post('verify-token/password/reset', {'email': email, 'token': code});
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in verifying reset code: $e');
      return OpStatus.unexpected(e.toString());
    }
  }

  Future<OpStatus> resetPassword(
    String code,
    String email,
    String newPassword,
  ) async {
    try {
      final response = await _net.post(
        'reset-password',
        {'token': code, 'email': email, 'newPassword': newPassword},
      );
      return OpStatus.fromResponse(response);
    } catch (e) {
      log('Error in resetting password: $e');
      return OpStatus.unexpected(e.toString());
    }
  }
}
