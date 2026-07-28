import 'dart:convert';
import 'dart:developer';

import 'package:auth_repo/src/models/models.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:net_source/net_source.dart';

/// Social authentication operations
class SocialAuth {
  SocialAuth(this._net, this._auth, this._googleSignIn);

  final NetSource _net;
  final fire_auth.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Logs in the user with a Google account.
  Future<OpStatus> continueWithGoogle([String type = 'login']) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      final googleAuth = await googleUser?.authentication;

      if (googleAuth != null) {
        final credential = fire_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCred = await _auth.signInWithCredential(credential);
        if (userCred.user != null) {
          final user = SocialUser(
            id: userCred.user!.uid,
            email: userCred.user!.email,
            displayName: userCred.user!.displayName,
            photo: userCred.user!.photoURL,
            provider: 'google',
            phone: userCred.user!.phoneNumber ?? '',
            metaData: jsonEncode({
              'emailVerified': userCred.user!.emailVerified,
              'providerId': userCred.user!.providerData[0].providerId,
              'uid': userCred.user!.providerData[0].uid,
              'displayName': userCred.user!.providerData[0].displayName,
              'photoUrl': userCred.user!.providerData[0].photoURL,
              'email': userCred.user!.providerData[0].email,
              'phoneNumber': userCred.user!.providerData[0].phoneNumber,
              'provider': userCred.user!.providerData[0].providerId,
            }),
          );

          final response = type == 'login'
              ? await _net.post('auth/Oauth/login', user.toJson())
              : await _net.post('auth/Oauth/signup', user.toJson());

          if (response.isSuccessful()) {
            // Note: _getAndAuthUser would be called from AuthCore
          }
          return OpStatus.fromResponse(response);
        }
      }
      return OpStatus.error('Error');
    } catch (e) {
      return OpStatus.unexpected(e.toString());
    }
  }
}
