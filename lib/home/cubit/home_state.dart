part of 'home_cubit.dart';

enum CaptureStatus { idle, listening, unavailable }

class HomeState extends Equatable {
  const HomeState({
    this.tabIndex = 0,
    this.needsReviewCount = 0,
    this.failedCaptureCount = 0,
    this.captureStatus = CaptureStatus.idle,
    this.backfilledCount = 0,
    this.captureError,
  });

  final int tabIndex;

  /// Transactions flagged needs_review or duplicate_suspect.
  final int needsReviewCount;

  /// Messages stored raw because no parser understood them.
  final int failedCaptureCount;
  final CaptureStatus captureStatus;
  final int backfilledCount;
  final String? captureError;

  /// What the Review badge shows.
  int get pendingCount => needsReviewCount + failedCaptureCount;

  HomeState copyWith({
    int? tabIndex,
    int? needsReviewCount,
    int? failedCaptureCount,
    CaptureStatus? captureStatus,
    int? backfilledCount,
    String? captureError,
  }) {
    return HomeState(
      tabIndex: tabIndex ?? this.tabIndex,
      needsReviewCount: needsReviewCount ?? this.needsReviewCount,
      failedCaptureCount: failedCaptureCount ?? this.failedCaptureCount,
      captureStatus: captureStatus ?? this.captureStatus,
      backfilledCount: backfilledCount ?? this.backfilledCount,
      captureError: captureError,
    );
  }

  @override
  List<Object?> get props => [
    tabIndex,
    needsReviewCount,
    failedCaptureCount,
    captureStatus,
    backfilledCount,
    captureError,
  ];
}
