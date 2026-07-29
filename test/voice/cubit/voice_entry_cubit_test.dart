import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/ai/transaction_extraction.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/voice/voice.dart';

import '../../support/test_harness.dart';

void main() {
  TransactionExtraction extraction({
    double confidence = 0.95,
    String? category = 'Transport',
    int? amountMinor = 5000,
  }) => TransactionExtraction(
    amountMinor: amountMinor,
    confidence: confidence,
    categoryGuess: category,
    merchantGuess: 'Taxi',
    paymentMethod: 'cash',
  );

  late AppServices services;

  /// Rebuilds the world with a scripted AI response. Called at the top
  /// of each test rather than in setUp, because the scripted extraction
  /// differs per case.
  Future<VoiceEntryCubit> cubitWith(FakeAiProvider provider) async {
    services = await createTestServices(aiProvider: provider);
    addTearDown(services.dispose);
    return VoiceEntryCubit(services.voicePipeline);
  }

  group('VoiceEntryCubit', () {
    test('auto-saves at the 0.85 threshold with a known category', () async {
      final cubit = await cubitWith(
        FakeAiProvider(extraction: extraction(confidence: 0.85)),
      );
      addTearDown(cubit.close);

      cubit.transcriptChanged('spent fifty kwacha on a taxi');
      await cubit.submit();

      expect(cubit.state.status, VoiceEntryStatus.autoSaved);
      expect(cubit.state.transaction!.amountMinor, 5000);
      expect(cubit.state.transaction!.status, TxStatus.confirmed.dbName);
      expect(cubit.state.transaction!.source, TxSource.voice.name);
    });

    test('routes to review just below the threshold', () async {
      final cubit = await cubitWith(
        FakeAiProvider(extraction: extraction(confidence: 0.84)),
      );
      addTearDown(cubit.close);

      cubit.transcriptChanged('maybe fifty on a taxi');
      await cubit.submit();

      expect(cubit.state.status, VoiceEntryStatus.needsReview);
      expect(cubit.state.transaction!.status, TxStatus.needsReview.dbName);
    });

    test('routes to review when the category is unknown', () async {
      final cubit = await cubitWith(
        FakeAiProvider(extraction: extraction(category: 'Interstellar')),
      );
      addTearDown(cubit.close);

      cubit.transcriptChanged('spent fifty kwacha');
      await cubit.submit();

      expect(
        cubit.state.status,
        VoiceEntryStatus.needsReview,
        reason:
            'High confidence alone must not auto-save an uncategorized '
            'entry',
      );
    });

    test('keeps the transcript when extraction fails', () async {
      final cubit = await cubitWith(FakeAiProvider(error: 'Network error'));
      addTearDown(cubit.close);

      cubit.transcriptChanged('spent fifty kwacha on a taxi');
      await cubit.submit();

      expect(cubit.state.status, VoiceEntryStatus.storedForReview);
      expect(cubit.state.errorMessage, isNotNull);
      expect(await services.rawCaptures.watchFailed().first, hasLength(1));
    });

    test('keeps the transcript when no amount was heard', () async {
      final cubit = await cubitWith(
        FakeAiProvider(extraction: extraction(amountMinor: null)),
      );
      addTearDown(cubit.close);

      cubit.transcriptChanged('I took a taxi today');
      await cubit.submit();

      expect(cubit.state.status, VoiceEntryStatus.storedForReview);
      expect(await services.rawCaptures.watchFailed().first, hasLength(1));
    });

    test('ignores an empty transcript', () async {
      final cubit = await cubitWith(
        FakeAiProvider(extraction: extraction()),
      );
      addTearDown(cubit.close);

      cubit.transcriptChanged('   ');
      await cubit.submit();

      expect(cubit.state.status, VoiceEntryStatus.editing);
    });

    blocTest<VoiceEntryCubit, VoiceEntryState>(
      'emits working before the result',
      build: () => VoiceEntryCubit(services.voicePipeline),
      setUp: () async {
        services = await createTestServices(
          aiProvider: FakeAiProvider(extraction: extraction()),
        );
        addTearDown(services.dispose);
      },
      act: (cubit) async {
        cubit.transcriptChanged('taxi to town');
        await cubit.submit();
      },
      verify: (cubit) => expect(cubit.state.status, VoiceEntryStatus.autoSaved),
    );
  });
}
