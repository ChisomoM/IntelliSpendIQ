import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Signed-in Firebase identity (separate from the local PIN app lock).
class IdentityUser {
  const IdentityUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;
}

/// Firebase Auth wrapper for register / sign-in / sign-out.
abstract interface class IdentityRepository {
  IdentityUser? get currentUser;

  Stream<IdentityUser?> get authStateChanges;

  Future<IdentityUser> register({
    required String email,
    required String password,
    String? displayName,
  });

  Future<IdentityUser> signIn({
    required String email,
    required String password,
  });

  Future<IdentityUser> signInWithGoogle();

  Future<void> signOut();

  Future<void> dispose();
}

class FirebaseIdentityRepository implements IdentityRepository {
  FirebaseIdentityRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  StreamSubscription<User?>? _sub;
  final _controller = StreamController<IdentityUser?>.broadcast();

  @override
  IdentityUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<IdentityUser?> get authStateChanges {
    _sub ??= _auth.authStateChanges().listen((user) {
      if (!_controller.isClosed) {
        _controller.add(_map(user));
      }
    });
    return _controller.stream;
  }

  @override
  Future<IdentityUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw StateError('Firebase Auth returned no user after register');
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
    return _map(user)!;
  }

  @override
  Future<IdentityUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw StateError('Firebase Auth returned no user after sign-in');
    }
    return _map(user)!;
  }

  @override
  Future<IdentityUser> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      final user = cred.user;
      if (user == null) {
        throw StateError('Firebase Auth returned no user after Google sign-in');
      }
      return _map(user)!;
    }

    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In did not return an ID token');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user;
    if (user == null) {
      throw StateError('Firebase Auth returned no user after Google sign-in');
    }
    return _map(user)!;
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }

  static IdentityUser? _map(User? user) {
    if (user == null) return null;
    return IdentityUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }
}
