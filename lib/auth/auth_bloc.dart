// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:developer';

import 'package:auth_repo/auth_repo.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:services_repo/services_repo.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.repo, this.sRepo) : super(const AuthState()) {
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthGuestRequested>(_onAuthGuestRequested);
    on<ProfileUpdated>(_onProfileUpdated);

    _authStatusSubscription = repo.status.listen(
      (status) {
        add(AuthStatusChanged(status));
      },
    );
    _serviceStatusSubscription = sRepo.authState.listen(
      (status) {
        if (status == 700) {
          repo.refreshAccessToken();
          // add(
          // const AuthStatusChanged(AuthStatus.expired),
          // ); // 700 is the status code for expired token
        }
        if (status == 800) {
          repo
            ..logOut()
            ..refreshSession();
        }
      },
    );
  }

  final AuthRepo repo;
  final ServicesRepo sRepo;
  late StreamSubscription<AuthStatus> _authStatusSubscription;
  late StreamSubscription<int> _serviceStatusSubscription;

  @override
  Future<void> close() {
    _authStatusSubscription.cancel();
    _serviceStatusSubscription.cancel();
    repo.dispose();
    return super.close();
  }

  bool first = true;

  Future<void> _onAuthGuestRequested(
    AuthGuestRequested event,
    Emitter<AuthState> emit,
  ) async {
    final appVersion = await repo.getAppVersion();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AuthStatus.guest,
        appVersion: appVersion,
      ),
    );
  }

  Future<void> _onProfileUpdated(
    ProfileUpdated event,
    Emitter<AuthState> emit,
  ) async {
    final user = await _tryGetUser();
    final userDetails = await repo.getUserDetails();
    if (isClosed) return;
    emit(
      state.copyWith(
        user: user,
        userDetails: userDetails,
      ),
    );
  }

  Future<void> _onAuthStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    var status = event.status;
    final user = await _tryGetUser();
    final appVersion = await repo.getAppVersion();
    if (user == null) {
      status = AuthStatus.unauthenticated;
    }
    if (user != null) {
      try {
        await repo.fetchUserDetails(user.id);
      } catch (e) {
        log('Error fetching user details: $e');
      }
    }
    final userDetails = await repo.getUserDetails();
    log('User Data $userDetails');
    if (isClosed) return;
    emit(
      state.copyWith(
        status: status,
        user: user,
        appVersion: appVersion,
        userDetails: userDetails,
      ),
    );
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await repo.logOut();
    add(const AuthStatusChanged(AuthStatus.unauthenticated));
  }

  Future<User?> _tryGetUser() async {
    try {
      final user = await repo.getUser();
      return user;
    } catch (_) {
      return null;
    }
  }
}
