import 'package:intellispendiq/domain/ai/transaction_extraction.dart';

/// LLM provider abstraction (D43). Feature code depends on this
/// interface only — never on a concrete vendor client — so the provider
/// is swappable without touching business logic.
abstract class AiProvider {
  /// Whether the provider is ready to make calls (e.g. API key present).
  Future<bool> get isConfigured;

  /// Extracts a structured transaction from a voice transcript.
  /// Throws [AiExtractionException] on failure; caller routes the item
  /// to the Review Inbox.
  Future<TransactionExtraction> extractTransaction({
    required String transcript,
    String locale = 'en',
  });

  // Phase 2+ (do not build yet):
  // Future<CategoryGuess> categorizeMerchant(...);
  // Future<String> narrate(...);
}
