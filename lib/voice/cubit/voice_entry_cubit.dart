import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';

part 'voice_entry_state.dart';

/// Quick-add by voice. Routing follows the pipeline's confidence rules
/// (D09, D53): auto-save at 0.85 or above with a known category,
/// otherwise the entry goes to review rather than being discarded.
class VoiceEntryCubit extends Cubit<VoiceEntryState> {
  VoiceEntryCubit(this._pipeline) : super(const VoiceEntryState());

  final VoicePipeline _pipeline;

  void transcriptChanged(String value) =>
      emit(state.copyWith(transcript: value));

  Future<void> submit() async {
    final transcript = state.transcript.trim();
    if (transcript.isEmpty) return;

    emit(state.copyWith(status: VoiceEntryStatus.working));
    final result = await _pipeline.processTranscript(transcript);

    emit(
      state.copyWith(
        status: switch (result.outcome) {
          VoiceOutcome.autoSaved => VoiceEntryStatus.autoSaved,
          VoiceOutcome.needsReview => VoiceEntryStatus.needsReview,
          VoiceOutcome.storedForReview => VoiceEntryStatus.storedForReview,
        },
        transaction: result.transaction,
        errorMessage: result.error,
      ),
    );
  }
}
