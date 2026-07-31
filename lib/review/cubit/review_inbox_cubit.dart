import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/raw_capture_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/raw_capture.dart';
import 'package:intellispendiq/domain/models/transaction.dart';

part 'review_inbox_state.dart';

/// Drives the Review Inbox: the one screen that must show everything a
/// human still needs to look at (plan §10.1).
///
/// Four repository streams feed one state object, so the view renders
/// from a single snapshot instead of nesting builders.
class ReviewInboxCubit extends Cubit<ReviewInboxState> {
  ReviewInboxCubit({
    required TransactionRepository transactions,
    required RawCaptureRepository rawCaptures,
    required TransferRepository transfers,
  }) : _transactions = transactions,
       _rawCaptures = rawCaptures,
       _transfers = transfers,
       super(const ReviewInboxState());

  final TransactionRepository _transactions;
  final RawCaptureRepository _rawCaptures;
  final TransferRepository _transfers;
  final _subscriptions = <StreamSubscription<void>>[];

  /// Starts watching the four review sources.
  void subscribe() {
    if (_subscriptions.isNotEmpty) return;
    emit(state.copyWith(status: ReviewInboxStatus.loading));

    _subscriptions.addAll([
      _transactions
          .watchByStatus(TxStatus.needsReview)
          .listen(
            (rows) => emit(
              state.copyWith(
                status: ReviewInboxStatus.loaded,
                needsReview: rows,
              ),
            ),
          ),
      _transactions
          .watchByStatus(TxStatus.duplicateSuspect)
          .listen(
            (rows) => emit(
              state.copyWith(
                status: ReviewInboxStatus.loaded,
                duplicates: rows,
              ),
            ),
          ),
      _rawCaptures.watchFailed().listen(
        (rows) => emit(
          state.copyWith(
            status: ReviewInboxStatus.loaded,
            failedCaptures: rows,
          ),
        ),
      ),
      _transactions.watchTransferCandidates().listen(
        (rows) => emit(
          state.copyWith(
            status: ReviewInboxStatus.loaded,
            transferCandidates: rows,
          ),
        ),
      ),
    ]);
  }

  /// Accepts a transaction as-is.
  Future<void> confirm(String transactionId) =>
      _transactions.confirm(transactionId);

  /// Assigns a category and confirms in one step — the common inbox
  /// action for an otherwise-complete entry.
  Future<void> categorize(String transactionId, String categoryId) =>
      _transactions.updateFields(
        transactionId,
        categoryId: categoryId,
        status: TxStatus.confirmed,
      );

  /// Drops a transaction the user judged to be a genuine duplicate.
  Future<void> discardDuplicate(String transactionId) =>
      _transactions.softDelete(transactionId);

  /// Marks a capture as not financial, so it stops asking for attention
  /// without deleting the original text.
  Future<void> ignoreCapture(String captureId) =>
      _rawCaptures.markIgnored(captureId, error: 'not_a_transaction');

  /// Confirms a suggested transfer pairing: links the two legs into a
  /// [Transfer] and soft-deletes them, which is what removes them from
  /// spend/income totals.
  Future<void> linkTransfer(TransferCandidate candidate) =>
      _transfers.linkTransfer(
        fromTransaction: candidate.debit,
        toTransaction: candidate.credit,
      );

  /// Declines a suggested transfer pairing — both legs stay as
  /// ordinary transactions and stop being re-suggested.
  Future<void> dismissTransferCandidate(TransferCandidate candidate) =>
      _transactions.dismissTransferCandidate(
        debitId: candidate.debit.id,
        creditId: candidate.credit.id,
      );

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }
}
