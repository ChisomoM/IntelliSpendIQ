part of 'auth_bloc.dart';

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user = User.empty,
      this.appVersion = '',
      this.userDetails,
  });

  final AuthStatus status;
  final User user;
  final UserDetails? userDetails;

  final String appVersion;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    double? balance,
    String? appVersion,
    UserDetails? userDetails,
  }) {
    return AuthState(
      user: user ?? this.user,
      status: status ?? this.status,
      appVersion: appVersion ?? this.appVersion,
      userDetails: userDetails ?? this.userDetails,
    );
  }

  @override
  List<Object?> get props => [status, user, appVersion, userDetails];
}
