import 'dart:async';

import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Everything the Review Inbox needs, in one snapshot.
class ReviewInboxState {
  const ReviewInboxState({
    this.needsReview = const [],
    this.duplicates = const [],
    this.failedCaptures = const [],
  });

  final List<TransactionRow> needsReview;
  final List<TransactionRow> duplicates;
  final List<RawCaptureRow> failedCaptures;

  bool get isEmpty =>
      needsReview.isEmpty && duplicates.isEmpty && failedCaptures.isEmpty;

  ReviewInboxState copyWith({
    List<TransactionRow>? needsReview,
    List<TransactionRow>? duplicates,
    List<RawCaptureRow>? failedCaptures,
  }) => ReviewInboxState(
    needsReview: needsReview ?? this.needsReview,
    duplicates: duplicates ?? this.duplicates,
    failedCaptures: failedCaptures ?? this.failedCaptures,
  );
}

/// Combines the three review sources into a single stream.
///
/// Nesting one `StreamBuilder` per source works but makes the widget
/// tree hard to read and is punishing on the analyzer, so the merge
/// happens here instead and the page renders from one snapshot.
Stream<ReviewInboxState> watchReviewInbox({
  required TransactionRepository transactions,
  required RawCaptureRepository rawCaptures,
}) {
  final controller = StreamController<ReviewInboxState>();
  var state = const ReviewInboxState();
  final subscriptions = <StreamSubscription<void>>[];

  void emit(ReviewInboxState next) {
    state = next;
    if (!controller.isClosed) controller.add(state);
  }

  controller.onListen = () {
    subscriptions.addAll([
      transactions
          .watchByStatus(TxStatus.needsReview)
          .listen((rows) => emit(state.copyWith(needsReview: rows))),
      transactions
          .watchByStatus(TxStatus.duplicateSuspect)
          .listen((rows) => emit(state.copyWith(duplicates: rows))),
      rawCaptures.watchFailed().listen(
        (rows) => emit(state.copyWith(failedCaptures: rows)),
      ),
    ]);
  };

  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
  };

  return controller.stream;
}
