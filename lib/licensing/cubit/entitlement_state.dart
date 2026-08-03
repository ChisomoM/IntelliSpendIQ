part of 'entitlement_cubit.dart';

enum EntitlementPhase {
  initial,
  loading,
  signedOut,
  needsNetwork,
  allowed,
  blocked,
  error,
}

class EntitlementState extends Equatable {
  const EntitlementState({
    this.phase = EntitlementPhase.initial,
    this.status = EntitlementStatus.unknown,
    this.license,
    this.errorMessage,
  });

  final EntitlementPhase phase;
  final EntitlementStatus status;
  final LicenseSnapshot? license;
  final String? errorMessage;

  bool get isResolved =>
      phase == EntitlementPhase.allowed ||
      phase == EntitlementPhase.blocked ||
      phase == EntitlementPhase.signedOut ||
      phase == EntitlementPhase.needsNetwork ||
      phase == EntitlementPhase.error;

  bool get isAllowed => phase == EntitlementPhase.allowed;

  EntitlementState copyWith({
    EntitlementPhase? phase,
    EntitlementStatus? status,
    LicenseSnapshot? license,
    String? errorMessage,
    bool clearLicense = false,
    bool clearError = false,
  }) {
    return EntitlementState(
      phase: phase ?? this.phase,
      status: status ?? this.status,
      license: clearLicense ? null : (license ?? this.license),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [phase, status, license, errorMessage];
}
