part of 'identity_cubit.dart';

class IdentityState extends Equatable {
  const IdentityState({
    this.user,
    this.busy = false,
    this.errorMessage,
  });

  final IdentityUser? user;
  final bool busy;
  final String? errorMessage;

  bool get isSignedIn => user != null;

  IdentityState copyWith({
    IdentityUser? user,
    bool? busy,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return IdentityState(
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [user, busy, errorMessage];
}
