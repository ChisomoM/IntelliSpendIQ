part of 'review_inbox_cubit.dart';

enum ReviewInboxStatus { initial, loading, loaded }

/// Everything the Review Inbox needs, in one snapshot.
class ReviewInboxState extends Equatable {
  const ReviewInboxState({
    this.status = ReviewInboxStatus.initial,
    this.needsReview = const [],
    this.duplicates = const [],
    this.failedCaptures = const [],
    this.transferCandidates = const [],
  });

  final ReviewInboxStatus status;
  final List<Transaction> needsReview;
  final List<Transaction> duplicates;
  final List<RawCapture> failedCaptures;
  final List<TransferCandidate> transferCandidates;

  bool get isEmpty =>
      needsReview.isEmpty &&
      duplicates.isEmpty &&
      failedCaptures.isEmpty &&
      transferCandidates.isEmpty;

  /// Total items awaiting a human glance.
  int get pendingCount =>
      needsReview.length +
      duplicates.length +
      failedCaptures.length +
      transferCandidates.length;

  ReviewInboxState copyWith({
    ReviewInboxStatus? status,
    List<Transaction>? needsReview,
    List<Transaction>? duplicates,
    List<RawCapture>? failedCaptures,
    List<TransferCandidate>? transferCandidates,
  }) {
    return ReviewInboxState(
      status: status ?? this.status,
      needsReview: needsReview ?? this.needsReview,
      duplicates: duplicates ?? this.duplicates,
      failedCaptures: failedCaptures ?? this.failedCaptures,
      transferCandidates: transferCandidates ?? this.transferCandidates,
    );
  }

  @override
  List<Object?> get props => [
    status,
    needsReview,
    duplicates,
    failedCaptures,
    transferCandidates,
  ];
}
