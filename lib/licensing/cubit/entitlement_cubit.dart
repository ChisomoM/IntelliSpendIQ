import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/identity_repository.dart';
import 'package:intellispendiq/data/repositories/license_repository.dart';
import 'package:intellispendiq/licensing/entitlement.dart';

part 'entitlement_state.dart';

class EntitlementCubit extends Cubit<EntitlementState> {
  EntitlementCubit({
    required IdentityRepository identity,
    required LicenseRepository license,
  }) : _identity = identity,
       _license = license,
       super(const EntitlementState());

  final IdentityRepository _identity;
  final LicenseRepository _license;

  Future<void> load() async {
    emit(state.copyWith(phase: EntitlementPhase.loading, clearError: true));
    final user = _identity.currentUser;
    if (user == null) {
      emit(
        state.copyWith(
          phase: EntitlementPhase.signedOut,
          clearLicense: true,
          status: EntitlementStatus.unknown,
        ),
      );
      return;
    }

    try {
      final cached = await _license.readCache();
      final license = await _license.ensureLicense(user: user);
      _emitFromLicense(license);
      // Prefer freshly ensured license; cached is fallback already handled.
      if (cached != null && cached.uid != user.uid) {
        await _license.clearCache();
      }
    } on LicenseNetworkRequiredException catch (e) {
      final cached = await _license.readCache();
      if (cached != null && cached.uid == user.uid) {
        _emitFromLicense(cached);
      } else {
        emit(
          state.copyWith(
            phase: EntitlementPhase.needsNetwork,
            status: EntitlementStatus.unknown,
            errorMessage: e.message,
          ),
        );
      }
    } on Object catch (e) {
      final cached = await _license.readCache();
      if (cached != null && cached.uid == user.uid) {
        _emitFromLicense(cached);
      } else {
        emit(
          state.copyWith(
            phase: EntitlementPhase.error,
            status: EntitlementStatus.unknown,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  void loadUnawaited() => load();

  Future<void> refresh() async {
    final user = _identity.currentUser;
    if (user == null) {
      emit(
        state.copyWith(
          phase: EntitlementPhase.signedOut,
          clearLicense: true,
          status: EntitlementStatus.unknown,
        ),
      );
      return;
    }
    try {
      final license = await _license.refreshIfOnline(user: user);
      if (license != null) {
        _emitFromLicense(license);
      } else {
        final cached = await _license.readCache();
        if (cached != null) {
          _emitFromLicense(cached);
        }
      }
    } on Object catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void refreshUnawaited() => refresh();

  /// Re-evaluate from the current license snapshot with the device clock
  /// (used on resume when offline).
  void reevaluate() {
    final license = state.license;
    if (license == null) return;
    _emitFromLicense(license);
  }

  Future<void> signOut() async {
    await _identity.signOut();
    await _license.clearCache();
    emit(
      state.copyWith(
        phase: EntitlementPhase.signedOut,
        clearLicense: true,
        status: EntitlementStatus.unknown,
        clearError: true,
      ),
    );
  }

  void _emitFromLicense(LicenseSnapshot license) {
    final status = EntitlementEvaluator.evaluate(
      license,
      now: DateTime.now().toUtc(),
    );
    final phase = EntitlementEvaluator.allowsAppAccess(status)
        ? EntitlementPhase.allowed
        : EntitlementPhase.blocked;
    emit(
      state.copyWith(
        phase: phase,
        status: status,
        license: license,
        clearError: true,
      ),
    );
  }
}
