import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/services/sms_sync_service.dart';

part 'home_state.dart';

/// Owns the shell: which tab is showing, and the badge that tells the
/// user how much is waiting in the Review Inbox.
///
/// Also kicks off SMS capture, which is why the badge matters — items
/// arrive here without the user doing anything.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required TransactionRepository transactions,
    required RawCaptureRepository rawCaptures,
    required SmsSyncService smsSync,
  }) : _transactions = transactions,
       _rawCaptures = rawCaptures,
       _smsSync = smsSync,
       super(const HomeState());

  final TransactionRepository _transactions;
  final RawCaptureRepository _rawCaptures;
  final SmsSyncService _smsSync;
  final _subscriptions = <StreamSubscription<void>>[];

  void tabSelected(int index) => emit(state.copyWith(tabIndex: index));

  /// Watches the pending counts that drive the Review badge.
  void watchPendingCount() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions.addAll([
      _transactions.watchReviewCount().listen(
        (count) => emit(state.copyWith(needsReviewCount: count)),
      ),
      _rawCaptures.watchFailedCount().listen(
        (count) => emit(state.copyWith(failedCaptureCount: count)),
      ),
    ]);
  }

  /// Fire-and-forget entry point for widget construction, where an
  /// awaited call is not possible.
  void startCaptureUnawaited() => unawaited(startCapture());

  /// Starts capture: live events first so nothing arriving during the
  /// backfill is missed. Ingest is idempotent, so the overlap is safe.
  ///
  /// A backfill failure (permission denied, OEM quirk) must never block
  /// the app — manual and voice entry still work, and the next launch
  /// retries from the stored watermark.
  Future<void> startCapture() async {
    _smsSync.startListening();
    try {
      final ingested = await _smsSync.backfill();
      if (isClosed) return;
      emit(
        state.copyWith(
          captureStatus: CaptureStatus.listening,
          backfilledCount: ingested,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          captureStatus: CaptureStatus.unavailable,
          captureError: '$error',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }
}
