import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

/// Outcome of a duplicate check before insert (plan §10.2).
sealed class DedupeOutcome {
  const DedupeOutcome();
}

/// No match — insert normally.
class DedupeNone extends DedupeOutcome {
  const DedupeNone();
}

/// Hard duplicate: same idempotency key already stored. Skip the insert
/// and link the raw capture to the existing transaction.
class DedupeHard extends DedupeOutcome {
  const DedupeHard(this.existing);

  final Transaction existing;
}

/// Fuzzy match: same amount + merchant + close time. Insert as
/// `duplicate_suspect` — the human decides, never silently dropped.
class DedupeFuzzy extends DedupeOutcome {
  const DedupeFuzzy(this.existing);

  final Transaction existing;
}

class DedupeService {
  DedupeService(this._transactions);

  final TransactionRepository _transactions;

  /// Normalized merchant equality is the Phase 1 similarity algorithm
  /// (plan §19); embeddings can replace this later.
  static String normalizeMerchant(String? merchant) => (merchant ?? '')
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim();

  Future<DedupeOutcome> check(
    TransactionDraft draft, {
    required String idempotencyKey,
  }) async {
    final hard = await _transactions.byIdempotencyKey(idempotencyKey);
    if (hard != null) return DedupeHard(hard);

    final candidates = await _transactions.fuzzyCandidates(
      amountMinor: draft.amountMinor,
      direction: draft.direction,
      transactedAt: draft.transactedAt,
    );
    final draftMerchant = normalizeMerchant(draft.merchant);
    for (final candidate in candidates) {
      final candidateMerchant = normalizeMerchant(candidate.merchant);
      final merchantsComparable =
          draftMerchant.isNotEmpty && candidateMerchant.isNotEmpty;
      if (!merchantsComparable || draftMerchant == candidateMerchant) {
        return DedupeFuzzy(candidate);
      }
    }
    return const DedupeNone();
  }
}
