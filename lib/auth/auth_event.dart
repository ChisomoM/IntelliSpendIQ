part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

/// {@template custom_auth_event}
/// Event added when some custom logic happens
/// {@endtemplate}
class AuthStatusChanged extends AuthEvent {
  const AuthStatusChanged(this.status);

  final AuthStatus status;

  @override
  List<Object> get props => [status];
}

class AuthenticateUser extends AuthEvent {
  const AuthenticateUser(this.user);

  final User user;

  @override
  List<Object> get props => [user];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthGuestRequested extends AuthEvent {}

class AuthBlockRequested extends AuthEvent {}

class ProfileUpdated extends AuthEvent {
  const ProfileUpdated();
}

class AuthRefreshRequested extends AuthEvent {}

class AuthDeleteRequested extends AuthEvent {}

class Expired extends AuthEvent {}
