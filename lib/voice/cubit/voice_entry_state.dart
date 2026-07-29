part of 'voice_entry_cubit.dart';

enum VoiceEntryStatus {
  editing,
  working,

  /// Confident enough to save without asking.
  autoSaved,

  /// Saved, but the user should check a detail.
  needsReview,

  /// Only the transcript was kept; extraction failed or was offline.
  storedForReview,
}

class VoiceEntryState extends Equatable {
  const VoiceEntryState({
    this.status = VoiceEntryStatus.editing,
    this.transcript = '',
    this.transaction,
    this.errorMessage,
  });

  final VoiceEntryStatus status;
  final String transcript;
  final TransactionRow? transaction;
  final String? errorMessage;

  bool get isWorking => status == VoiceEntryStatus.working;

  VoiceEntryState copyWith({
    VoiceEntryStatus? status,
    String? transcript,
    TransactionRow? transaction,
    String? errorMessage,
  }) {
    return VoiceEntryState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      transaction: transaction ?? this.transaction,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, transcript, transaction, errorMessage];
}
