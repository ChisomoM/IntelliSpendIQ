import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/voice/voice_pipeline.dart';

import '../../support/test_harness.dart';

void main() {
  TransactionExtraction extraction({
    int? amountMinor = 5000,
    double confidence = 0.95,
    String? category = 'Transport',
    String direction = 'debit',
    String? date,
  }) => TransactionExtraction(
    amountMinor: amountMinor,
    confidence: confidence,
    categoryGuess: category,
    merchantGuess: 'Taxi',
    paymentMethod: 'cash',
    direction: direction,
    date: date,
  );

  group('auto-save threshold', () {
    test('saves as confirmed at or above 0.85 with a category', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(extraction: extraction(confidence: 0.85)),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript(
        'spent fifty kwacha on a taxi',
      );

      expect(result.outcome, VoiceOutcome.autoSaved);
      expect(result.transaction!.status, TxStatus.confirmed.dbName);
      expect(result.transaction!.amountMinor, 5000);
      expect(result.transaction!.source, TxSource.voice.name);
      expect(result.transaction!.confidence, 0.85);
    });

    test('routes to review just below the threshold', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(extraction: extraction(confidence: 0.84)),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript(
        'maybe fifty on a taxi',
      );

      expect(result.outcome, VoiceOutcome.needsReview);
      expect(result.transaction!.status, TxStatus.needsReview.dbName);
    });

    test('routes to review when the category is missing', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(
          extraction: extraction(confidence: 0.99, category: null),
        ),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript(
        'spent fifty kwacha',
      );

      expect(
        result.outcome,
        VoiceOutcome.needsReview,
        reason:
            'High confidence alone must not auto-save an uncategorized '
            'entry',
      );
    });

    test('routes to review when the category is not one we know', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(
          extraction: extraction(category: 'Interstellar Travel'),
        ),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript('...');

      expect(result.outcome, VoiceOutcome.needsReview);
      expect(result.transaction!.categoryId, isNull);
    });
  });

  group('never drops a transcript', () {
    test('keeps the transcript when extraction fails', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(error: 'Network error'),
      );
      addTearDown(services.dispose);

      const transcript = 'spent fifty kwacha on a taxi';
      final result = await services.voicePipeline.processTranscript(transcript);

      expect(result.outcome, VoiceOutcome.storedForReview);
      final raw = await services.rawCaptures.byId(result.rawCapture!.id);
      expect(raw!.body, transcript);
      expect(raw.parseStatus, ParseStatus.failed.name);
      expect(await services.rawCaptures.watchFailed().first, hasLength(1));
    });

    test('keeps the transcript when no API key is configured', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(configured: false),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript('a taxi');

      expect(result.outcome, VoiceOutcome.storedForReview);
      expect(result.error, isNotNull);
      expect(await services.rawCaptures.watchFailed().first, hasLength(1));
    });

    test('keeps the transcript when no amount could be heard', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(
          extraction: extraction(amountMinor: null),
        ),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript(
        'I took a taxi today',
      );

      expect(result.outcome, VoiceOutcome.storedForReview);
      expect(result.transaction, isNull);
      expect(await services.rawCaptures.watchFailed().first, hasLength(1));
    });
  });

  group('field defaults', () {
    test('defaults the payment method to cash', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(extraction: extraction()),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript('taxi');
      expect(result.transaction!.paymentMethod, 'cash');
    });

    test('uses the spoken date when one was extracted', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(
          extraction: extraction(date: '2026-07-20'),
        ),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript(
        'taxi last Monday',
      );
      expect(
        DateTime.parse(result.transaction!.transactedAt).toUtc(),
        DateTime.parse('2026-07-20').toUtc(),
      );
    });

    test('records a credit when the extraction says received', () async {
      final services = await createTestServices(
        aiProvider: FakeAiProvider(
          extraction: extraction(direction: 'credit', category: 'Income'),
        ),
      );
      addTearDown(services.dispose);

      final result = await services.voicePipeline.processTranscript(
        'received fifty kwacha',
      );
      expect(result.transaction!.direction, TxDirection.credit.name);
    });
  });

  test('two identical transcripts are stored separately', () async {
    // Saying "fifty kwacha for a taxi" twice usually means two taxis.
    // Only SMS has provider references strong enough to dedupe on.
    final services = await createTestServices(
      aiProvider: FakeAiProvider(extraction: extraction()),
    );
    addTearDown(services.dispose);

    await services.voicePipeline.processTranscript('taxi to town');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await services.voicePipeline.processTranscript(
      'taxi to town',
    );

    expect(second.outcome, isNot(VoiceOutcome.storedForReview));
    expect(
      await services.transactions.watchRecent().first,
      hasLength(2),
      reason:
          'Both utterances must be kept — neither is provably a '
          're-delivery of the other',
    );
  });
}
