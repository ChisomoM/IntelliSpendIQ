import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/identity_repository.dart';
import 'package:intellispendiq/data/repositories/license_repository.dart';

part 'identity_state.dart';

class IdentityCubit extends Cubit<IdentityState> {
  IdentityCubit({
    required IdentityRepository identity,
    required LicenseRepository license,
  }) : _identity = identity,
       _license = license,
       super(const IdentityState()) {
    _sub = _identity.authStateChanges.listen((user) {
      emit(state.copyWith(user: user, clearUser: user == null));
    });
  }

  final IdentityRepository _identity;
  final LicenseRepository _license;
  StreamSubscription<IdentityUser?>? _sub;

  Future<void> load() async {
    emit(state.copyWith(user: _identity.currentUser, clearError: true));
  }

  void loadUnawaited() => load();

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final user = await _identity.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _license.ensureLicense(user: user);
      emit(state.copyWith(busy: false, user: user));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(busy: false, errorMessage: _mapAuthError(e)));
    } on Object catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final user = await _identity.signIn(email: email, password: password);
      await _license.ensureLicense(user: user);
      emit(state.copyWith(busy: false, user: user));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(busy: false, errorMessage: _mapAuthError(e)));
    } on Object catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final user = await _identity.signInWithGoogle();
      await _license.ensureLicense(user: user);
      emit(state.copyWith(busy: false, user: user));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(busy: false, errorMessage: _mapAuthError(e)));
    } on Object catch (e) {
      final message = e.toString();
      if (message.contains('canceled') || message.contains('cancelled')) {
        emit(state.copyWith(busy: false, clearError: true));
        return;
      }
      emit(state.copyWith(busy: false, errorMessage: message));
    }
  }

  Future<void> signOut() async {
    await _identity.signOut();
    await _license.clearCache();
    emit(state.copyWith(clearUser: true, clearError: true));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }

  static String _mapAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'An account already exists for that email.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use a password with at least 6 characters.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Incorrect email or password.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      _ => e.message ?? 'Authentication failed.',
    };
  }
}
