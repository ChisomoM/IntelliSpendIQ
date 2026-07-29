part of 'pin_setup_cubit.dart';

enum PinSetupStep { verifyCurrent, choose, confirm }

enum PinSetupStatus { editing, submitting, success }

class PinSetupState extends Equatable {
  const PinSetupState({
    this.step = PinSetupStep.choose,
    this.status = PinSetupStatus.editing,
    this.entry = '',
    this.chosen = '',
    this.errorMessage,
  });

  final PinSetupStep step;
  final PinSetupStatus status;

  /// What is currently in the field.
  final String entry;

  /// The PIN picked at [PinSetupStep.choose], awaiting confirmation.
  final String chosen;
  final String? errorMessage;

  String get title => switch (step) {
    PinSetupStep.verifyCurrent => 'Enter your current PIN',
    PinSetupStep.choose => 'Choose a PIN',
    PinSetupStep.confirm => 'Enter it again',
  };

  bool get isBusy => status == PinSetupStatus.submitting;

  PinSetupState copyWith({
    PinSetupStep? step,
    PinSetupStatus? status,
    String? entry,
    String? chosen,
    String? errorMessage,
  }) {
    return PinSetupState(
      step: step ?? this.step,
      status: status ?? this.status,
      entry: entry ?? this.entry,
      chosen: chosen ?? this.chosen,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [step, status, entry, chosen, errorMessage];
}
