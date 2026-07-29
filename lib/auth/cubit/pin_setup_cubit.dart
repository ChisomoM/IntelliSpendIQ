import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';

part 'pin_setup_state.dart';

/// The set-a-PIN / change-a-PIN form.
///
/// Kept separate from `AuthCubit` because it is a short-lived, per-page
/// concern, while the auth session outlives every screen.
class PinSetupCubit extends Cubit<PinSetupState> {
  /// Set [requireCurrentPin] when an existing PIN is being replaced.
  PinSetupCubit(this._auth, {bool requireCurrentPin = false})
    : super(
        PinSetupState(
          step: requireCurrentPin
              ? PinSetupStep.verifyCurrent
              : PinSetupStep.choose,
        ),
      );

  final AppLockRepository _auth;

  void pinChanged(String value) => emit(state.copyWith(entry: value));

  /// Advances one step, or commits on the last one.
  Future<void> submit() async {
    if (state.status == PinSetupStatus.submitting) return;
    final entry = state.entry;

    switch (state.step) {
      case PinSetupStep.verifyCurrent:
        emit(state.copyWith(status: PinSetupStatus.submitting));
        if (!await _auth.verifyPin(entry)) {
          emit(
            state.copyWith(
              status: PinSetupStatus.editing,
              entry: '',
              errorMessage: 'That is not your current PIN.',
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            status: PinSetupStatus.editing,
            step: PinSetupStep.choose,
            entry: '',
          ),
        );

      case PinSetupStep.choose:
        if (!AppLockRepository.isValidPin(entry)) {
          emit(
            state.copyWith(
              errorMessage:
                  'Use ${AppLockRepository.minPinLength}'
                  '–${AppLockRepository.maxPinLength} digits.',
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            step: PinSetupStep.confirm,
            chosen: entry,
            entry: '',
          ),
        );

      case PinSetupStep.confirm:
        if (entry != state.chosen) {
          // Send them back to the start rather than letting them retype
          // the confirmation against a PIN they may have mistyped.
          emit(
            state.copyWith(
              step: PinSetupStep.choose,
              entry: '',
              chosen: '',
              errorMessage: 'Those did not match. Try again.',
            ),
          );
          return;
        }
        emit(state.copyWith(status: PinSetupStatus.submitting));
        await _auth.setPin(entry);
        emit(state.copyWith(status: PinSetupStatus.success, entry: ''));
    }
  }

  /// For button callbacks, which may not discard a future.
  void submitUnawaited() => unawaited(submit());
}
