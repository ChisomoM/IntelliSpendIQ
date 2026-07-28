/// Result of transcribing a recorded utterance.
sealed class TranscriptionResult {
  const TranscriptionResult();
}

class TranscriptionSuccess extends TranscriptionResult {
  const TranscriptionSuccess(this.transcript);

  final String transcript;
}

class TranscriptionFailure extends TranscriptionResult {
  const TranscriptionFailure(this.reason);

  final String reason;
}

/// Speech-to-text abstraction (D50). The preferred implementation is
/// whisper.cpp on-device (`tiny`/`base` models, English only); the
/// binding is evaluated at integration time, so the pipeline depends on
/// this interface rather than a specific package.
abstract class TranscriptionService {
  /// Whether an on-device model is available and ready.
  Future<bool> get isAvailable;

  /// Transcribes the audio file at [audioPath] (16 kHz mono WAV).
  Future<TranscriptionResult> transcribe(String audioPath);
}

/// Placeholder until the whisper.cpp binding is wired in (Phase 1d
/// evaluation). Voice entry still works via typed quick-add; recordings
/// route to the Review Inbox rather than being dropped.
class UnavailableTranscriptionService implements TranscriptionService {
  const UnavailableTranscriptionService();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async =>
      const TranscriptionFailure(
        'On-device transcription model not installed yet',
      );
}
