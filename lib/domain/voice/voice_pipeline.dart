import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/ai/ai_provider.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/models/capture_input.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

enum VoiceOutcome {
  /// Confidence ≥ threshold and required fields present → saved confirmed.
  autoSaved,

  /// Saved as needs_review (low confidence / missing fields).
  needsReview,

  /// Transcript stored raw only; extraction failed or offline.
  storedForReview,
}

class VoiceResult {
  const VoiceResult(
    this.outcome, {
    this.transaction,
    this.rawCapture,
    this.error,
  });

  final VoiceOutcome outcome;
  final Transaction? transaction;
  final RawCapture? rawCapture;
  final String? error;
}

/// Voice entry pipeline (plan §9):
/// transcript → persist raw → Claude extraction (online) → confidence
/// routing. Auto-save only at confidence ≥ 0.85 with amount AND category
/// present (D09, D53); anything less lands in the Review Inbox. The
/// transcript is always persisted first — never dropped.
class VoicePipeline {
  VoicePipeline({
    required AiProvider aiProvider,
    required RawCaptureRepository rawCaptures,
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required CategoryRepository categories,
  }) : _ai = aiProvider,
       _rawCaptures = rawCaptures,
       _transactions = transactions,
       _accounts = accounts,
       _categories = categories;

  static const double autoSaveThreshold = 0.85;

  final AiProvider _ai;
  final RawCaptureRepository _rawCaptures;
  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;

  Future<VoiceResult> processTranscript(String transcript) async {
    final now = DateTime.now();
    final input = CaptureInput(
      channel: CaptureChannel.voiceTranscript,
      body: transcript,
      receivedAt: now,
    );
    final hash = Ids.contentHash(
      sender: 'voice',
      body: transcript,
      receivedAt: now,
    );
    final raw = await _rawCaptures.insert(input, contentHash: hash);

    if (!await _ai.isConfigured) {
      await _rawCaptures.markFailed(
        raw.id,
        error: 'AI extraction unavailable (no API key configured)',
      );
      return VoiceResult(
        VoiceOutcome.storedForReview,
        rawCapture: raw,
        error: 'AI extraction is not configured',
      );
    }

    TransactionExtraction extraction;
    try {
      extraction = await _ai.extractTransaction(transcript: transcript);
    } on AiExtractionException catch (error) {
      await _rawCaptures.markFailed(raw.id, error: error.message);
      return VoiceResult(
        VoiceOutcome.storedForReview,
        rawCapture: raw,
        error: error.message,
      );
    }

    if (extraction.amountMinor == null || extraction.amountMinor! <= 0) {
      await _rawCaptures.markFailed(raw.id, error: 'No amount extracted');
      return VoiceResult(
        VoiceOutcome.storedForReview,
        rawCapture: raw,
        error: 'Could not hear an amount',
      );
    }

    final category = extraction.categoryGuess == null
        ? null
        : await _categories.byName(extraction.categoryGuess!);
    final transactedAt = extraction.date == null
        ? now
        : DateTime.tryParse(extraction.date!) ?? now;

    final autoSave =
        extraction.confidence >= autoSaveThreshold && category != null;

    final draft = TransactionDraft(
      amountMinor: extraction.amountMinor!,
      direction: extraction.direction == 'credit'
          ? TxDirection.credit
          : TxDirection.debit,
      source: TxSource.voice,
      transactedAt: transactedAt,
      currency: extraction.currency,
      merchant: extraction.merchantGuess,
      description: transcript,
      categoryId: category?.id,
      paymentMethod: extraction.paymentMethod ?? 'cash',
      confidence: extraction.confidence,
      metadata: {'transcript': transcript},
    );

    // Each utterance is its own event: unlike an SMS re-delivery, saying
    // the same thing twice usually means it happened twice, and there is
    // no provider reference to prove otherwise. Keying on the capture id
    // keeps both — the fuzzy duplicate check surfaces genuine repeats.
    final transaction = await _transactions.insertDraft(
      draft,
      accountId: (await _accounts.getDefault()).id,
      idempotencyKey: 'voice:${raw.id}',
      status: autoSave ? TxStatus.confirmed : TxStatus.needsReview,
      rawCaptureId: raw.id,
    );
    await _rawCaptures.markParsed(
      raw.id,
      parserKey: 'voice',
      transactionId: transaction.id,
    );

    return VoiceResult(
      autoSave ? VoiceOutcome.autoSaved : VoiceOutcome.needsReview,
      transaction: transaction,
      rawCapture: raw,
    );
  }
}
