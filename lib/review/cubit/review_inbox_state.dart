part of 'review_inbox_cubit.dart';

enum ReviewInboxStatus { initial, loading, loaded }

/// Everything the Review Inbox needs, in one snapshot.
class ReviewInboxState extends Equatable {
  const ReviewInboxState({
    this.status = ReviewInboxStatus.initial,
    this.needsReview = const [],
    this.duplicates = const [],
    this.failedCaptures = const [],
  });

  final ReviewInboxStatus status;
  final List<TransactionRow> needsReview;
  final List<TransactionRow> duplicates;
  final List<RawCaptureRow> failedCaptures;

  bool get isEmpty =>
      needsReview.isEmpty && duplicates.isEmpty && failedCaptures.isEmpty;

  /// Total items awaiting a human glance.
  int get pendingCount =>
      needsReview.length + duplicates.length + failedCaptures.length;

  ReviewInboxState copyWith({
    ReviewInboxStatus? status,
    List<TransactionRow>? needsReview,
    List<TransactionRow>? duplicates,
    List<RawCaptureRow>? failedCaptures,
  }) {
    return ReviewInboxState(
      status: status ?? this.status,
      needsReview: needsReview ?? this.needsReview,
      duplicates: duplicates ?? this.duplicates,
      failedCaptures: failedCaptures ?? this.failedCaptures,
    );
  }

  @override
  List<Object?> get props => [
    status,
    needsReview,
    duplicates,
    failedCaptures,
  ];
}
