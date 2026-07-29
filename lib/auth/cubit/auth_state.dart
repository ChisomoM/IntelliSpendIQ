part of 'auth_cubit.dart';

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.pin = '',
    this.submitting = false,
    this.canUseBiometrics = false,
    this.attemptsRemaining,
    this.retryAt,
    this.errorMessage,
  });

  final AuthStatus status;

  /// The PIN being typed. Held in memory only, cleared on every
  /// outcome — it is never written anywhere.
  final String pin;
  final bool submitting;

  /// Whether the lock screen should offer the biometric button.
  final bool canUseBiometrics;
  final int? attemptsRemaining;

  /// When the cooldown expires, if one is in force.
  final DateTime? retryAt;
  final String? errorMessage;

  /// Whether the app content may be shown. [AuthStatus.unregistered]
  /// counts: a user who never set a PIN is not locked out.
  bool get isUnlocked =>
      status == AuthStatus.authenticated || status == AuthStatus.unregistered;

  bool get isResolved => status != AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    String? pin,
    bool? submitting,
    bool? canUseBiometrics,
    int? attemptsRemaining,
    DateTime? retryAt,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      pin: pin ?? this.pin,
      submitting: submitting ?? this.submitting,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      attemptsRemaining: attemptsRemaining,
      retryAt: retryAt ?? this.retryAt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pin,
    submitting,
    canUseBiometrics,
    attemptsRemaining,
    retryAt,
    errorMessage,
  ];
}
