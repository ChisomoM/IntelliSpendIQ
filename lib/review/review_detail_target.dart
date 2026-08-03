import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intellispendiq/domain/models/transaction.dart';

/// Which inbox item the Review details page is showing.
sealed class ReviewDetailTarget {
  const ReviewDetailTarget();
}

/// A capture that needs a category or confidence confirmation.
final class NeedsReviewDetail extends ReviewDetailTarget {
  const NeedsReviewDetail(this.transaction);
  final Transaction transaction;
}

/// A confirmed entry that auto-saved without a category (typically SMS).
final class UncategorizedDetail extends ReviewDetailTarget {
  const UncategorizedDetail(this.transaction);
  final Transaction transaction;
}

/// A possible duplicate of an existing entry.
final class DuplicateReviewDetail extends ReviewDetailTarget {
  const DuplicateReviewDetail(this.transaction);
  final Transaction transaction;
}

/// A debit/credit pair that looks like a transfer between accounts.
final class TransferCandidateDetail extends ReviewDetailTarget {
  const TransferCandidateDetail(this.candidate);
  final TransferCandidate candidate;
}

/// A message no parser understood.
final class FailedCaptureDetail extends ReviewDetailTarget {
  const FailedCaptureDetail(this.capture);
  final RawCapture capture;
}
